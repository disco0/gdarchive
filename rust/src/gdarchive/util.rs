use gdnative::core_types::{GodotString, PoolArray};

pub type PoolByteArray = PoolArray<u8>;
pub type PoolStringArray = PoolArray<GodotString>;

// pub static ERR_OK:     i32 = gdnative::sys::godot_error_GODOT_OK;
// pub static ERR_FAILED: i32 = gdnative::sys::godot_error_GODOT_FAILED;

// @NOTE: get_dirs doesn't work, I don't know if this is necessary?
pub fn is_directory_string(path_str: &String) -> bool
{
    path_str.ends_with("/")
}