use gdnative::core_types::GodotResult;
use gdnative::prelude::*;
use gdnative::api::*;
use gdnative::api::ProjectSettings;

use zip;
use zip::ZipArchive;

use std::io::Read;

use itertools::Itertools;

use crate::gdarchive::archive::ArchiveReader;
use crate::gdarchive::zip::result::*;
use crate::gdarchive::util::{PoolStringArray, PoolByteArray, *};


macro_rules! set_failed
{
    ($self:expr) => {{
        $self._read_fail = true;
        return PoolStringArray::new();
    }};

    ($self:expr, $l:expr) => {{
        $self._read_fail = true;
        return $l;
    }};
}

#[derive(NativeClass)]
#[inherit(Resource)]
#[register_with(Self::_register_methods)]
pub struct ZipReader
{
    _file:      Option<Ref<File, Unique>>,
    _zip:       Option<ZipArchive<std::fs::File>>,
    _zip_paths: Vec::<String>,

    #[property]
    path:       String,
    /// Used to indicate a returned empty *Array is failure vs. actually empty
    #[property(no_editor, get)]
    _read_fail: bool,
    #[property]
    trace:      bool,
}

impl ArchiveReader for ZipReader
{
    fn _close(&mut self) -> GodotResult
    {
        self._file.as_ref().map(|file| file.close());
        self._zip = None;
        self.path = "".to_string();
        self._read_fail = false;
        Ok(())
    }

    fn _get_paths(&mut self) -> PoolStringArray
    {
        self._read_fail = false;
        if let Some(built_paths) = self.build_paths()
        {
            if self.trace
            {
                let paths: PoolStringArray =
                             built_paths.into_iter()
                                        .map(GodotString::from_str)
                                        .collect();
                self._log(format!{ "Resolved {} paths.", paths.len() });
                paths
            }
            else
            {
                built_paths.into_iter()
                           .map(GodotString::from_str)
                           .collect()
            }
        }
        else { set_failed!(self) }
    }

    fn _get_files(&mut self) -> PoolStringArray
    {
        self._read_fail = false;
        if let Some(paths) = self.build_paths()
        {
            paths.into_iter()
                 .filter(|path| !is_directory_string(path))
                 .map(GodotString::from_str)
                 .collect()
        }
        else { set_failed!(self) }
    }

    fn _get_dirs(&mut self) -> PoolStringArray
    {
        self._read_fail = false;
        if let Some(paths) = self.build_paths()
        {
            paths.into_iter()
                 .filter(is_directory_string)
                 .map(GodotString::from_str)
                 .collect::<PoolStringArray>()
        }
        else { set_failed!(self) }
    }

    fn _has_path(&mut self, p_path: String) -> bool
    {
        self._read_fail = false;
        if self._zip.is_none()
        {
            godot_error!("Zip file not opened yet.");
            return false;
        }

        if self._zip_paths.is_empty()
        {
            self.collect_zip_paths()
        }

        self._zip_paths.contains(&p_path)
    }

    fn _read_file(&mut self, p_path: String) -> PoolByteArray
    {
        self._read_fail = false;
        let mut bytes = PoolByteArray::new();
        if self._zip.is_none()
        {
            godot_error!("Zip file not opened yet.");
            return bytes;
        }
        else
        {
            let zip_reader = self
                ._zip
                .as_mut()
                .expect("Attempted to read files in uninitialized zip archive");

            if let Ok(mut zip_file) = zip_reader.by_name(&p_path)
            {
                if zip_file.is_file()
                {
                    let inflated_size = zip_file.size() as usize;
                    let mut inflated = Vec::with_capacity(inflated_size);
                    let _ = zip_file.read_to_end(&mut inflated)
                                    .and_then(|_| Ok(bytes.append_vec(&mut inflated)))
                                    .or_else(|_| Err(godot_error!("Archive file read_to_end failed.")));
                }
                else
                {
                    godot_error!(" -> path is not a file in archive: {}", p_path);
                }
            }
        }

        bytes
    }
}

impl ZipReader
{
    fn _log(&mut self, msg: String)
    {
        if self.trace { godot_print!("[ZipFileReader] {}", msg) }
    }
}

#[methods]
impl ZipReader
{
    fn _register_methods(_builder: &ClassBuilder<Self>)
    {
    }

    /// The "constructor" of the class.
    fn new(_base: &Resource) -> Self
    {
        ZipReader {
            _file:      None,
            _zip:       None,
            _zip_paths: Vec::<String>::new(),
            path:       "".to_string(),
            _read_fail: false,
            trace:      false,
        }
    }

    #[method]
    fn open(&mut self, p_path: String) -> i32
    {
        self.close();
        self._log(format!{"Opening {}", p_path});

        let ps = ProjectSettings::godot_singleton();
        let global_path = ps.globalize_path(p_path.clone()).to_string();

        let gdfile = File::new();
        if gdfile.file_exists(p_path.clone())
        {
            if let Ok(_) = gdfile.open(p_path, File::READ)
            {
                let file =
                    std::fs::File::open(global_path.clone())
                                  .expect("Failed to open std file handle");
                let reader =
                    zip::ZipArchive::new(file)
                    .expect("Failed to open reader for zip file.");
                self._zip = Some(reader);
                self._file = Some(gdfile);
                self.path = global_path.clone();

                ZipReadErr::OK.into()
            }
            else
            {
                ZipReadErr::ERROR.into()
            }
        }
        else
        {
            godot_error!("Failed to open archive at path {:?}: does not exist", p_path);
            ZipReadErr::ERROR.into()
        }
    }

    #[method]
    fn close(&mut self) -> i32
    {
        if self._close().is_ok() { 0 }
        else { 1 }
    }

    /// Internal path builder
    fn build_paths(&mut self) -> Option<Vec<String>>
    {
        if self._zip.is_none()
        {
            godot_error!("Zip file not opened yet.");
        }

        if self._zip_paths.is_empty()
        {
            self.collect_zip_paths();
        }

        Some(self._zip_paths.clone())
    }

    #[method]
    fn get_paths(&mut self) -> PoolStringArray
    {
        self._get_paths()
    }

    #[method]
    fn get_files(&mut self) -> PoolStringArray
    {
        self._get_files()
    }

    #[method]
    fn get_dirs(&mut self) -> PoolStringArray
    {
        self._get_dirs()
    }

    #[method]
    fn has_path(&mut self, p_path: String) -> bool
    {
        self._has_path(p_path)
    }

    fn collect_zip_paths(&mut self)
    {
        self._zip_paths = self._zip
            .as_ref()
            .expect("Attempted reference of uninitialized zip archive reference")
            .file_names()
            .map(String::from)
            .sorted()
            .collect::<Vec::<String>>();
    }

    #[method]
    fn read_file(&mut self, p_path: String) -> PoolByteArray
    {
        self._log(format!{ "Reading file: {p_path}" });
        self._read_file(p_path)
    }
}

/// @TODO: Align interface to [Godot `4.0` implementation](https://docs.godotengine.org/en/stable/classes/class_zipreader.html).
/// ideally use this trait directly (via mixin?) but for now just mirror it
pub trait GodotZipReader
{
    fn open(&mut self, p_path: GodotString) -> i32;
    fn close(&mut self, p_path: GodotString) -> i32;

	fn get_files(&mut self) -> PoolStringArray;
	fn read_file(&mut self, p_path: GodotString, p_case_sensitive: bool) -> PoolArray<u8>;
}