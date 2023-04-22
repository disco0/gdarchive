use gdnative::prelude::*;
use gdnative::api::*;
use gdnative::api::ProjectSettings;

use zip;
use zip::result::ZipError;
use zip::write::FileOptions;

use std::fs::File;
use std::io::{Read, Seek, Write};
use std::path::Path;
use path_slash::PathExt;

use walkdir::{DirEntry, WalkDir};

use crate::gdarchive::result::ZipWriteErr;


#[derive(NativeClass)]
#[inherit(Resource)]
#[register_with(Self::_register_methods)]
pub struct ZipFileWriter
{
    #[property]
    output_path: String,
    #[property]
    source_dir:  String,
    method:      zip::CompressionMethod,
    #[property]
    trace:       bool
}

#[methods]
impl ZipFileWriter
{
    fn _register_methods(_builder: &ClassBuilder<Self>)
    {
        // godot_print!("Registering ZipFileWriter");
    }

    fn new(_base: &Resource) -> Self
    {
        // godot_print!("Initializing ZipFileWriter");
        ZipFileWriter {
            output_path: "".to_string(),
            source_dir:  "".to_string(),
            method:      zip::CompressionMethod::Deflated,
            trace:       false,
        }
    }

    #[method]
    fn write_zip(&mut self) -> ZipWriteErr {
        if self.trace {
            godot_print!("writing archive");
        }

        let ps = ProjectSettings::godot_singleton();

        let global_source_dir = ps.globalize_path(self.source_dir.clone()).to_string();
        let source_path = Path::new(global_source_dir.as_str());
        if let Ok(res) = Path::try_exists(source_path) {
            if !res {
                godot_error!("Source path not found: {global_source_dir}");
                return ZipWriteErr::ERROR
            }
        }

        let global_output_path = ps.globalize_path(self.output_path.clone()).to_string();

        if let Err(err) = self._write_zip(global_source_dir, global_output_path)
        {
            godot_error!("Error creating zip file: {err}");
            ZipWriteErr::ERROR
        }
        else { ZipWriteErr::OK }
    }

    ///
    /// Based on `zip` crate's [write_dir.rs](https://github.com/zip-rs/zip/blob/master/examples/write_dir.rs) example
    ///
    fn zip_dir<T>(&mut self,
        it: &mut dyn Iterator<Item = DirEntry>,
        prefix: String,
        writer: T
    ) -> zip::result::ZipResult<()>
    where
        T: Seek + Write,
    {
        let mut zip = zip::ZipWriter::new(writer);
        let options = FileOptions::default()
            .compression_method(self.method)
            .unix_permissions(0o755);

        let mut buffer = Vec::new();
        for entry in it {
            let path = entry.path();
            let name = path.strip_prefix(Path::new(prefix.as_str())).unwrap();

            // Write file or directory explicitly
            // Some unzip tools unzip files with directory paths correctly, some do not!
            if path.is_file() {
                if self.trace {
                    let (slashed, slashed_name) = (PathExt::to_slash(path), PathExt::to_slash(name));
                    if slashed.is_some() && slashed_name.is_some()
                    {
                        godot_print!("adding file \"{}\" as \"{}\"", slashed.unwrap(), slashed_name.unwrap());
                    }
                    else
                    {
                        godot_print!("adding file {path:?} as {name:?} ...");
                    }
                }

                #[allow(deprecated)]
                zip.start_file_from_path(name, options)?;
                let mut f = File::open(path)?;

                f.read_to_end(&mut buffer)?;
                zip.write_all(&buffer)?;
                buffer.clear();
            } else if !name.as_os_str().is_empty() {
                // Only if not root! Avoids path spec / warning
                // and mapname conversion failed error on unzip

                if self.trace { godot_print!("adding dir {:?} as {name:?} ...", PathExt::to_slash(path)) }

                #[allow(deprecated)]
                zip.add_directory_from_path(name, options)?;
            }
        }

        zip.finish()?;
        Result::Ok(())
    }

    fn _write_zip(
        &mut self,
        src_dir: String,
        dst_file: String
    ) -> zip::result::ZipResult<()> {

        let src_dir_str = src_dir.as_str();
        if !Path::new(src_dir_str).is_dir() {
            return Err(ZipError::FileNotFound);
        }

        let path = Path::new(&dst_file);
        let file = File::create(path).unwrap();

        let walkdir = WalkDir::new(src_dir.clone());
        let it = walkdir.into_iter();

        self.zip_dir(&mut it.filter_map(|e| e.ok()),
                    src_dir.clone(),
                    file)?;

        Ok(())
    }

    fn _log(&mut self, msg: String)
    {
        if self.trace { godot_print!("[ZipFileWriter] {}", msg) }
    }
}