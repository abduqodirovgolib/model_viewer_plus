package com.example.model_viewer_plus

import android.app.Activity
import android.content.Context
import android.content.MutableContextWrapper
import com.google.android.filament.utils.Utils
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import java.nio.ByteBuffer

class ModelViewerPlusPlatformView(
    private val context: Context,
    messenger: BinaryMessenger,
    id: Int,
    creationParams: Any?
) : PlatformView, MethodChannel.MethodCallHandler {
    // This is the view that will be returned to Flutter
    private var customView: ModelView
    private val methodChannel = MethodChannel(messenger, "model_viewer_plus_$id")

    init {
        // Workaround to get the activity from the context
        val v = (context as MutableContextWrapper).baseContext as Activity
        // Initialize the custom view
        customView = ModelView(v)

        // O'z o'qi atrofida aylanish — creationParams dan
        @Suppress("UNCHECKED_CAST")
        val params = creationParams as? Map<String, Any?>
        val autoRotationSpeed = (params?.get("autoRotationSpeed") as? Number)?.toFloat() ?: 30f
        customView.setAutoRotationSpeed(autoRotationSpeed)

        methodChannel.setMethodCallHandler(this)
    }

    // This is the main handler that will be used to post tasks to the main thread
    companion object {
        init {
            Utils.init()
        }
    }

    // This method is called when Flutter requests the view
    override fun getView(): ModelView = customView

    // This method is called when the view is destroyed
    override fun dispose() {}

    // This method is called when Flutter sends a message to the platform
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "loadModel" -> {
                val modelBytes = call.argument<ByteArray>("modelBytes")
                val modelName = call.argument<String>("modelName")

                if (modelBytes != null && modelName != null) {
                    val buffer = ByteBuffer.wrap(modelBytes)
                    customView.setModel(buffer, modelName)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENT", "modelBytes or modelName is null", null)
                }
            }

            "loadEnvironment" -> {
                val iblBytes = call.argument<ByteArray>("iblBytes")

                if (iblBytes != null) {
                    val iblBuffer = ByteBuffer.wrap(iblBytes)
                    customView.setLights(iblBuffer)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENT", "Environment bytes are null", null)
                }
            }

            else -> result.notImplemented()
        }
    }
}