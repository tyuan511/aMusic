//! Android glue: cpal's AAudio backend asks `ndk-context` for the JavaVM and an
//! application `Context` (to query device ids and sample rates), so the Kotlin
//! plugin hands both over once at start-up.

use std::ffi::c_void;
use std::ptr;

use jni_sys::{jclass, jobject, JNIEnv, JavaVM};

/// `AmusicEnginePlugin.nativeInit(context)`; called once from `onAttachedToEngine`.
///
/// # Safety
/// Called by the JVM with a valid `env` and application `context`.
#[no_mangle]
pub unsafe extern "system" fn Java_com_tangge_amusic_1engine_AmusicEnginePlugin_nativeInit(
    env: *mut JNIEnv,
    _class: jclass,
    context: jobject,
) {
    let mut vm: *mut JavaVM = ptr::null_mut();
    if ((**env).v1_2.GetJavaVM)(env, &mut vm) != 0 || vm.is_null() {
        return;
    }
    // Leaked on purpose: the context must outlive every audio stream.
    let global = ((**env).v1_2.NewGlobalRef)(env, context);
    ndk_context::initialize_android_context(vm.cast::<c_void>(), global.cast::<c_void>());
}
