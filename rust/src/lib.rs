mod archive_reader;
use crate::archive_reader::zip_file_reader::ZipFileReader;
use crate::archive_reader::zip_file_writer::ZipFileWriter;
use gdnative::prelude::{godot_init, InitHandle/*, godot_print*/};

// Function that registers all exposed classes to Godot
fn init(handle: InitHandle) {
    // godot_print!("Registering {}", "ZipFileReader");
    handle.add_class::<ZipFileReader>();
    // godot_print!("Registering {}", "ZipFileWriter");
    handle.add_class::<ZipFileWriter>();
}

// macros that create the entry-points of the dynamic library.
godot_init!(init);
