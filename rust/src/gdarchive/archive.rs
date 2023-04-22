use gdnative::prelude::*;
use gdnative::core_types::GodotResult;
use crate::gdarchive::util::*;

pub (crate) trait ArchiveWriter
{
    fn _set_root_dir(&mut self, path: String);
    fn _write_archive(&mut self, path: String) -> bool;
}

pub (crate) trait ArchiveReader
{
    fn _close(&mut self) -> GodotResult;
    fn _get_paths(&mut self) -> PoolStringArray;
    fn _get_files(&mut self) -> PoolStringArray;
    fn _get_dirs(&mut self) -> PoolStringArray;
    fn _has_path(&mut self, path: String) -> bool;
    fn _read_file(&mut self, path: String) -> PoolArray::<u8>;
}

/// @TODO: Align interface to [Godot `4.0` implementation](https://docs.godotengine.org/en/stable/classes/class_zipreader.html).
/// ideally use this trait directly (via mixin?) but for now just mirror it
pub (crate) trait GodotZipReader
{
    fn open(&mut self, p_path: GodotString) -> i32;
    fn close(&mut self, p_path: GodotString) -> i32;

	fn get_files(&mut self) -> PoolStringArray;
	fn read_file(&mut self, p_path: GodotString, p_case_sensitive: bool) -> PoolArray<u8>;
}