package com.tangge.amusic_engine

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * The engine itself is reached over FFI; this class only hands the application
 * context to the native library (cpal's AAudio backend needs it).
 */
class AmusicEnginePlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        System.loadLibrary("amusic_engine")
        nativeInit(binding.applicationContext)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {}

    private external fun nativeInit(context: Context)
}
