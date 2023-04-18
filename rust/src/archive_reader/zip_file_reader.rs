use gdnative::prelude::*;
use gdnative::api::*;
use gdnative::api::ProjectSettings;
use gdnative::core_types::PoolArray;

use zip;
use zip::ZipArchive;

use std::io::Read;

use itertools::Itertools;

use crate::archive_reader::archive_read_err::ZipReadErr;
use crate::archive_reader::archive_reader::ArchiveReader;

macro_rules! set_failed
{
    ($self:expr) => {{
        $self._read_fail = true;
        return PoolArray::<GodotString>::new();
    }};

    ($self:expr, $l:expr) => {{
        $self._read_fail = true;
        return $l;
    }};
}

#[derive(NativeClass)]
#[inherit(Resource)]
#[register_with(Self::_register_methods)]
pub struct ZipFileReader
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


impl ArchiveReader for ZipFileReader
{
    fn _close(&mut self) //  -> u32 {
    {
        self._file.as_ref().map(|file| file.close());
        self._zip = None;
        self.path = "".to_string();
        self._read_fail = false;
    }

    fn _get_paths(&mut self) -> PoolArray::<GodotString>
    {
        self._read_fail = false;
        if let Some(built_paths) = self.build_paths()
        {
            if self.trace
            {
                let paths: PoolArray::<GodotString> =
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

    fn _get_files(&mut self) -> PoolArray::<GodotString>
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

    fn _get_dirs(&mut self) -> PoolArray::<GodotString>
    {
        self._read_fail = false;
        if let Some(paths) = self.build_paths()
        {
            paths.into_iter()
                 .filter(is_directory_string)
                 .map(GodotString::from_str)
                 .collect::<PoolArray::<GodotString>>()
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

    fn _read_file(&mut self, p_path: String) -> PoolArray<u8>
    {
        self._read_fail = false;
        let mut bytes = PoolArray::<u8>::new();
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

#[methods]
impl ZipFileReader
{
    fn _register_methods(_builder: &ClassBuilder<Self>)
    {
        godot_print!("Registering ZipFileReader");
    }

    /// The "constructor" of the class.
    fn new(_base: &Resource) -> Self
    {
        // godot_print!("Initializing ZipFileReader instance");
        ZipFileReader {
            _file:      None,
            _zip:       None,
            _zip_paths: Vec::<String>::new(),
            path:       "".to_string(),
            _read_fail: false,
            trace:      false,
        }
    }

    #[method]
    fn open(&mut self, p_path: String) -> ZipReadErr
    {
        self.close();
        self._log(format!{"Opening {}", p_path});

        let ps = ProjectSettings::godot_singleton();
        let global_path = ps.globalize_path(p_path.clone()).to_string();

        let gdfile = File::new();
        let fs_file_path = global_path.clone();
        let self_path = global_path.clone();
        if gdfile.file_exists(p_path.to_string())
        {
            if let Ok(_) = gdfile.open(p_path, File::READ)
            {
                let file =
                    std::fs::File::open(fs_file_path)
                                  .expect("Failed to open std file handle");
                let reader =
                    zip::ZipArchive::new(file)
                    .expect("Failed to open reader for zip file.");
                self._zip = Some(reader);
                self._file = Some(gdfile);
                self.path = self_path;
                ZipReadErr::OK
            }
            else
            {
                ZipReadErr::ERROR
            }
        }
        else
        {
            godot_error!("Failed to open archive at path {:?}: does not exist", p_path);
            ZipReadErr::ERROR
        }
    }

    #[method]
    fn close(&mut self) //  -> u32 {
    {
        self._close()
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
    fn get_paths(&mut self) -> PoolArray::<GodotString>
    {
        self._get_paths()
    }

    #[method]
    fn get_files(&mut self) -> PoolArray::<GodotString>
    {
        self._get_files()
    }

    #[method]
    fn get_dirs(&mut self) -> PoolArray::<GodotString>
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
    fn read_file(&mut self, p_path: String) -> PoolArray<u8>
    {
        self._log(format!{ "Reading file: {p_path}" });
        self._read_file(p_path)
    }

    fn _log(&mut self, msg: String)
    {
        if self.trace { godot_print!("[ZipFileReader] {}", msg) }
    }
}

//#region free

// @NOTE: get_dirs doesn't work, I don't know if this is necessary?
fn is_directory_string(str: &String) -> bool
{
    str.ends_with("/")
}

//#endregion free