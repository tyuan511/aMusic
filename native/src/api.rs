pub enum Platform {
    Unknown,
    Android,
    Ios,
    Windows,
    Unix,
    MacOs(String),
    Wasm,
}

pub fn platform() -> Platform {
    if cfg!(windows) {
        Platform::Windows
    } else if cfg!(target_os = "android") {
        Platform::Android
    } else if cfg!(target_os = "ios") {
        Platform::Ios
    } else if cfg!(all(target_os = "macos", target_arch = "aarch64")) {
        Platform::MacOs("Apple Silicon".into())
    } else if cfg!(target_os = "macos") {
        Platform::MacOs("Intel".into())
    } else if cfg!(target_family = "wasm") {
        Platform::Wasm
    } else if cfg!(unix) {
        Platform::Unix
    } else {
        Platform::Unknown
    }
}
