use gdnative::core_types::{ PoolArray, GodotString };

pub (crate) trait ArchiveReader
{
    // fn _open(&mut self, path: String) -> ZipReadErr;
    fn _close(&mut self);
    fn _get_paths(&mut self) -> PoolArray::<GodotString>;
    fn _get_files(&mut self) -> PoolArray::<GodotString>;
    fn _get_dirs(&mut self) -> PoolArray::<GodotString>;
    fn _has_path(&mut self, path: String) -> bool;
    fn _read_file(&mut self, path: String) -> PoolArray::<u8>;
}