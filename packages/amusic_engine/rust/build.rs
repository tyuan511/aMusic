//! Android only: oboe-sys compiles C++ but leaves the C++ runtime out of the
//! final link (rustc links with `-nodefaultlibs`). The new/delete, exception
//! and vtable symbols then stay undefined; old Androids export some of them
//! from libc, current ones do not, and the library fails to load. Appending
//! the static libc++ here puts it after every object that needs it.
fn main() {
    if std::env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("android") {
        println!("cargo:rustc-link-arg-cdylib=-lc++_static");
        println!("cargo:rustc-link-arg-cdylib=-lc++abi");
    }
}
