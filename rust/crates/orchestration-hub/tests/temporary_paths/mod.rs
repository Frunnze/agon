pub fn temporary_path(path_inside_temporary_folder: &str) -> String {
    let path = std::env::temp_dir().join(path_inside_temporary_folder);
    path.display().to_string()
}
