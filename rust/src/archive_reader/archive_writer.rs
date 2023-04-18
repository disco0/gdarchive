use gdnative::core_types::{ ByteArray, StringArray };

pub (crate) trait ArchiveWriter
{
    fn _set_root_dir(&mut self, path: String);
    fn _write_archive(&mut self, path: String) -> bool;
}