use gdnative::prelude::*;
use gdnative::api::*;
use gdnative::api::ProjectSettings;
use gdnative::core_types::{ByteArray, StringArray};

use zip;
use zip::{ ZipArchive, read::ZipFile };

use std::io::BufReader;
use std::io::Read;

use bytes::{ Buf, Bytes };

use crate::archive_reader::zip_read_err::*;
use crate::archive_reader::reader::ArchiveReader;

#[derive(NativeClass)]
#[inherit(Resource)]
#[register_with(Self::_register_methods)]
pub struct ZipPoolByteArrayReader
{
    _buf:       Option<Bytes>,
    _zip:       Option<ZipArchive<Bytes>>,
    _zip_paths: Vec::<String>,
    #[property]
    path:       String,
}

impl ArchiveReader for ZipPoolByteArrayReader
{
    fn _close(&mut self) //  -> u32 {
    {
        self._buf = None;
        self._zip = None;
        self.path = "".to_string();
    }

    fn _get_paths(&mut self) -> StringArray
    {
        if let Some(paths) = self.build_paths()
        {
            paths.into_iter()
                 .map(GodotString::from_str)
                 .collect()
        }
        else { StringArray::new() }
    }

    fn _get_files(&mut self) -> StringArray
    {
        if let Some(paths) = self.build_paths()
        {
            paths.into_iter()
                 .filter(|path| !is_directory_string(path))
                 .map(GodotString::from_str)
                 .collect()
        }
        else { StringArray::new() }
    }

    fn _get_dirs(&mut self) -> StringArray
    {
        if let Some(paths) = self.build_paths()
        {
            paths.into_iter()
                 .filter(is_directory_string)
                 .map(GodotString::from_str)
                 .collect()
        }
        else { StringArray::new() }
    }

    fn _has_path(&mut self, p_path: String) -> bool
    {
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

    fn _read_file(&mut self, p_path: String) -> ByteArray
    {
        let mut bytes = ByteArray::new();
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
                    if let Ok(_read_size) = zip_file.read_to_end(&mut inflated)
                    {
                        // godot_print!(" -> Read {} bytes.", read_size)
                        bytes.append_vec(&mut inflated);
                    }
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
impl ZipPoolByteArrayReader
{
    fn _register_methods(_builder: &ClassBuilder<Self>)
    {
        godot_print!("Initialized ZipPoolByteArrayReader")
    }

    /// The "constructor" of the class.
    fn new(_base: &Resource) -> Self
    {
        godot_print!("Initializing ZipFileReader");
        ZipPoolByteArrayReader {
            _buf: None,
            _zip: None,
            _zip_paths: Vec::<String>::new(),
            path: "".to_string()
        }
    }

    fn build_buf(&mut self, byte_arr: ByteArray)
    {
        // let mut reader = Bytes::from().as_mut().reader();
        // let mut reader = BufReader::new(buf);

        let mut zip_reader = ZipArchive::new(byte_arr.to_vec());
    }

    fn from_zipfile(&mut self, zip_file: ZipFile)
    {
        // let mut reader = Bytes::from().as_mut().reader();
        // let mut reader = BufReader::new(buf);

        let mut zip_reader = ZipArchive::new(zip_file.bytes());
    }

    #[method]
    fn open(&mut self, buf: ByteArray) -> ZipReadErr
    {

        self.close();
        godot_print!("Opening {}", p_path);

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
        } else {
            godot_error!("Failed to open archive at path {}", p_path);
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
    fn get_paths(&mut self) -> StringArray
    {
        self._get_paths()
    }

    #[method]
    fn get_files(&mut self) -> StringArray
    {
        self._get_files()
    }

    #[method]
    fn get_dirs(&mut self) -> StringArray
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
            .expect("Attempted reference uninitialized zip archive reference")
            .file_names()
            .map(String::from)
            .collect();
    }

    #[method]
    fn read_file(&mut self, p_path: String) -> ByteArray
    {
        self._read_file(p_path)
    }
}
