package com.tangge.amusic_engine

import io.flutter.embedding.engine.plugins.FlutterPlugin

/** The engine itself is reached over FFI; this class only loads the native library. */
class AmusicEnginePlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        System.loadLibrary("amusic_engine")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {}
}
