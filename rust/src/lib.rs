use gdnative::prelude::{godot_init, InitHandle};

mod gdarchive;
use gdarchive::zip::{ ZipFileWriter, ZipBufferReader };
use gdarchive::godot::{ ZipPacker, ZipReader };

// Function that registers all exposed classes to Godot
fn init(handle: InitHandle) {
    handle.add_tool_class::<ZipReader>();
    handle.add_tool_class::<ZipPacker>();
    handle.add_tool_class::<ZipFileWriter>();
    handle.add_tool_class::<ZipBufferReader>();
}

// macros that create the entry-points of the dynamic library.
godot_init!(init);
