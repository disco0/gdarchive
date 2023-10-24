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