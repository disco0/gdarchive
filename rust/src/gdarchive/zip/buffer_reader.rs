use std::env::temp_dir;
use std::fs;
use std::io::Read;
use std::io::Write;

use gdnative::prelude::*;
use gdnative::api::*;
use gdnative::core_types::GodotResult;

use zip::{self, ZipArchive};

use crate::gdarchive::archive::ArchiveReader;
use crate::gdarchive::util::*;
use crate::gdarchive::result::*;


#[derive(NativeClass)]
#[inherit(Resource)]
#[register_with(Self::_register_methods)]
pub struct ZipBufferReader
{
    _buf:       Option<PoolByteArray>,
    _zip:       Option<ZipArchive<std::fs::File>>,
    _zip_paths: Vec::<String>,
    // #[property]
    // path:       String,
}

impl ArchiveReader for ZipBufferReader
{
    fn _close(&mut self) -> GodotResult
    {
        self._buf = None;
        self._zip = None;
        self._zip_paths.clear();

        Ok(())
    }

    fn _get_paths(&mut self) -> PoolStringArray
    {
        if let Some(paths) = self.build_paths()
        {
            paths.into_iter()
                 .map(GodotString::from_str)
                 .collect()
        }
        else { PoolStringArray::new() }
    }

    fn _get_files(&mut self) -> PoolStringArray
    {
        if let Some(paths) = self.build_paths()
        {
            paths.into_iter()
                 .filter(|path| !is_directory_string(path))
                 .map(GodotString::from_str)
                 .collect()
        }
        else { PoolStringArray::new() }
    }

    fn _get_dirs(&mut self) -> PoolStringArray
    {
        if let Some(paths) = self.build_paths()
        {
            paths.into_iter()
                 .filter(is_directory_string)
                 .map(GodotString::from_str)
                 .collect()
        }
        else { PoolStringArray::new() }
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

    fn _read_file(&mut self, p_path: String) -> PoolByteArray
    {
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
impl ZipBufferReader
{
    fn _register_methods(_builder: &ClassBuilder<Self>)
    {
        godot_print!("Initialized ZipBufferReader")
    }

    /// The "constructor" of the class.
    fn new(_base: &Resource) -> Self
    {
        godot_print!("Initializing ZipFileReader");
        ZipBufferReader {
            _buf: None,
            _zip: None,
            _zip_paths: Vec::<String>::new(),
            // path: "".to_string()
        }
    }

    // this is a mess lol
    #[method]
    fn open(&mut self, buf: PoolByteArray) -> i32
    {
        self.close();
        godot_print!("Loading buffer {} byte buffer", buf.len());
        let rng = RandomNumberGenerator::new();
        rng.randomize();
        let mut tmp_file_path = temp_dir();
        let tmp_filename = format!{"zip-buffer-{}", rng.randi().to_string()};
        let binding = tmp_file_path.clone();
        let tmp_file_path_display = binding.display();
        tmp_file_path.set_file_name(tmp_filename.clone());

        let _buf_tmp_file = fs::File::options().create(true).open(tmp_file_path);
        match _buf_tmp_file
        {
            Ok(mut file) =>
            {
                godot_print!{"Created temp backing file for buffer."};
                match file.write(&buf.read()[..])
                {
                    Ok(cnt) =>
                    {
                        godot_print!{"Wrote {cnt} bytes to temp backing file."}

                        if let Ok(zip) = ZipArchive::new(file)
                        {
                            self._zip = Some(zip);
                            ERR_OK
                        }
                        else
                        {
                            godot_error!{"Failed to initialize zip reader for buffer tmp file. (path: {tmp_file_path_display}, filename: {tmp_filename})" };
                            ERR_FAILED
                        }
                    }
                    Err(err) =>
                    {
                        godot_error!{"Failed to write buffe to temp backing file (error: {err})"};
                        ERR_FAILED
                    }
                }
            }
            Err(err) =>
            {
                godot_error!{"Failed to initialize backing file for zip buffer content (error: {err}) (path: {tmp_file_path_display}, filename: {tmp_filename})" };
                ERR_FAILED
            }
        }
    }

    #[method]
    fn close(&mut self) -> i32
    {
        if self._close().is_ok() { ERR_OK } else { ERR_FAILED }
    }

    // fn build_buf(&self, byte_arr: PoolByteArray)
    // {
    //     // let mut reader = Bytes::from().as_mut().reader();
    //     // let mut reader = BufReader::new(buf);
    //     let byte_arr = byte_arr;

    //     let mut zip_reader = ZipArchive::new(byte_arr.read().into());
    // }

    // fn from_zipfile(&mut self, zip_file: ZipFile)
    // {
    //     // let mut reader = Bytes::from().as_mut().reader();
    //     // let mut reader = BufReader::new(buf);

    //     let mut zip_reader = ZipArchive::new(zip_file.bytes().into());
    // }

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
            .expect("Attempted reference uninitialized zip archive reference")
            .file_names()
            .map(String::from)
            .collect();
    }

    #[method]
    fn read_file(&mut self, p_path: String) -> PoolByteArray
    {
        self._read_file(p_path)
    }
}
