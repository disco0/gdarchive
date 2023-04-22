mod gdarchive;
use gdarchive::zip::{ ZipFileReader, ZipFileWriter, ZipBufferReader };
use gdarchive::godot::zip_packer::ZipPacker;

use gdnative::prelude::{godot_init, InitHandle};

// Function that registers all exposed classes to Godot
fn init(handle: InitHandle) {
    handle.add_tool_class::<ZipFileReader>();
    handle.add_tool_class::<ZipFileWriter>();
    handle.add_tool_class::<ZipBufferReader>();
    handle.add_tool_class::<ZipPacker>();
}

// macros that create the entry-points of the dynamic library.
godot_init!(init);
