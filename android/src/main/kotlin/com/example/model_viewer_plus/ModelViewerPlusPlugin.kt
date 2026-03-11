package com.example.model_viewer_plus

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger

/** ModelViewerPlusPlugin */
class ModelViewerPlusPlugin: FlutterPlugin {
    private lateinit var factory: ModelViewerPlusFactory

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        val messenger: BinaryMessenger = flutterPluginBinding.binaryMessenger
        factory = ModelViewerPlusFactory(messenger)
        flutterPluginBinding.platformViewRegistry.registerViewFactory("model_viewer_plus", factory)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {}
}
