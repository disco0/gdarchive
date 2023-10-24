use gdnative::prelude::*;
use gdnative::api::*;
use gdnative::api::ProjectSettings;

use zip;
use zip::ZipWriter;
use zip::write::FileOptions;

use std::io::Write;

use crate::gdarchive::zip::zipappend::ZipAppend;
use crate::gdarchive::result::{ ERR_OK, ERR_FAILED };

type ZipWriterFile = ZipWriter<std::fs::File>;


#[derive(NativeClass)]
#[inherit(Resource)]
#[register_with(Self::_register_methods)]
pub struct ZipPacker
{
    _file:      Option<Ref<File, Unique>>,
    _zip:       Option<ZipWriterFile>,
    trace:      bool,
    _mode:      ZipAppend,
    _options:   FileOptions,
}

impl ZipPacker
{
    fn _register_methods(_builder: &ClassBuilder<Self>)
    {
        //godot_print!("Registering ZipFileReader");
    }

    fn _log(&self, msg: String)
    {
        if self.trace { godot_print!("[ZipPacker] {}", msg); };
    }
}

#[methods]
impl GodotZipPacker for ZipPacker
{
    fn new(_base: &Resource) -> Self
    {
        // godot_print!("Initializing ZipPacker instance");
        ZipPacker {
            _file:    None,
            _zip:     None,
            trace:    false,
            _mode:    Default::default(),
            _options: FileOptions::default().compression_method(zip::CompressionMethod::Deflated),
        }
    }

    #[method]
    fn open(&mut self, p_path: GodotString, #[opt] p_append: ZipAppend) -> i32
    {
        self.close();
        self._log(format!{"Opening {}", p_path});

        let global_path = ProjectSettings::godot_singleton()
                                        .globalize_path(p_path.clone()).to_string();

        let fs_file_path = global_path.clone();

        let _fs_path_string = fs_file_path.to_string();
        let fs_path = std::path::Path::new(&_fs_path_string);

        self._mode = p_append;
        self._log(format!{"Opening file at path \"{global_path}\""});

        let file =
            std::path::Path::try_exists(fs_path)
                .and_then(|_|
                {
                    std::fs::OpenOptions::new().write(true).open(fs_file_path.clone())
                })
                .or_else(|_|
                {
                    // @TODO: Properly error out
                    std::fs::File::create(fs_file_path.clone())
                })
                .or_else(|_|  {
                    godot_error!{"Failed to create archive output file at path {fs_file_path}"};
                    Err(ERR_FAILED)
                });

        if let Ok(_file) = file
        {
            self._zip = Some(ZipWriter::new(_file));
            ERR_OK
        }
        else
        {
            godot_error!("Failed to open std::fs::File handle for writing");
            ERR_FAILED
        }
    }

    #[method]
    fn close(&mut self) -> i32
    {
        if let Some(file) = self._file.as_mut()
        {
            file.close();
            self._file = None;
        }

        let mut _old_zip = self._zip.take();
        if let Some(writer) = _old_zip.as_mut()
        {
            if let Err(err) = writer.finish()
            {
                godot_error!{"ZipWriter finish call failed (error: {})", err.to_string()};
                ERR_FAILED
            }
            else { ERR_OK }
        }
        else { ERR_OK }
    }

    #[method]
    fn close_file(&mut self) -> i32
    {
        // uhhhhh not needed here?
        ERR_OK
    }

    #[method]
    fn start_file(&mut self, p_path: GodotString) -> i32
    {
        match self._zip.as_mut()
        {
            Some(zip) =>
                zip.start_file(p_path.to_string(), self._options)
                    .and_then(|_| Ok(ERR_OK))
                    .unwrap_or_else(|_|
                    {
                        godot_error!("Failed to start file write.");
                        ERR_FAILED
                    }),
            None =>
            {
                godot_error!("Zip file not opened yet.");
                ERR_FAILED
            }
        }
    }

    #[method]
    fn write_file(&mut self, p_data: PoolArray::<u8> ) -> i32
    {
        self._log(format!{"Writing {} bytes to zip", p_data.len()});

        if let Some(zip) = self._zip.as_mut()
        {
            zip.write_all(&p_data.read())
                .and_then(|_| Ok(ERR_OK))
                .unwrap_or_else(|_|
                {
                    godot_error!("Failed to write file data to zip");
                    ERR_FAILED
                })
        }
        else
        {
            godot_error!{"write_file called before initialization"};
            ERR_FAILED
        }
    }
}

/// @TODO: Align interface to [Godot `4.0` implementation](https://docs.godotengine.org/en/stable/classes/class_zipreader.html).
/// ideally use this trait directly (via mixin?) but for now just mirror it
pub (crate) trait GodotZipPacker
{
    fn new(_base: &Resource) -> Self;
	fn open(&mut self, p_path: GodotString, p_append: ZipAppend) -> i32;
	fn close(&mut self) -> i32;
	fn start_file(&mut self, p_path: GodotString) -> i32;
	fn write_file(&mut self, p_data: PoolArray::<u8>) -> i32;
	fn close_file(&mut self) -> i32;
}