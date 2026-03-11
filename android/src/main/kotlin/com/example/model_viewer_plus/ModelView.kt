package com.example.model_viewer_plus

import android.annotation.SuppressLint
import android.app.Activity
import android.app.Application
import android.content.Context
import android.os.Bundle
import android.util.AttributeSet
import android.util.Log
import android.view.Choreographer
import android.view.GestureDetector
import android.view.LayoutInflater
import android.view.TextureView
import android.widget.LinearLayout
import com.google.android.filament.Fence
import com.google.android.filament.View
import com.google.android.filament.utils.AutomationEngine
import com.google.android.filament.utils.KTX1Loader
import java.nio.ByteBuffer

/**
 * A custom view for rendering and interacting with 3D models using Filament.
 */
class ModelView : LinearLayout {

    private val TAG = "ModelView"

    // UI components
    private lateinit var textureView: TextureView
    private lateinit var choreographer: Choreographer
    private val frameScheduler = FrameCallback()
    private lateinit var modelViewer: CustomModelViewer

    // State variables
    private var loadStartTime = 0L
    private var loadStartFence: Fence? = null
    private val viewerContent = AutomationEngine.ViewerContent()
    private var autoScaleEnabled = true
    private var modelLoaded = false

    // Constructors
    constructor(context: Context?) : super(context) { init(context) }
    constructor(context: Context?, attrs: AttributeSet?) : super(context, attrs) { init(context) }
    constructor(context: Context?, attrs: AttributeSet?, defStyleAttr: Int) : super(context, attrs, defStyleAttr) { init(context) }

    /**
     * Initializes the view and its components.
     * @param context The context in which the view is running.
     */
    @SuppressLint("ClickableViewAccessibility")
    private fun init(context: Context?) {
        val inflated = LayoutInflater.from(context).inflate(R.layout.custom_view, this, true)
        textureView = inflated.findViewById(R.id.main_sv)

        choreographer = Choreographer.getInstance()
        modelViewer = CustomModelViewer(textureView)
        viewerContent.view = modelViewer.view
        viewerContent.sunlight = modelViewer.light
        viewerContent.lightManager = modelViewer.engine.lightManager
        viewerContent.scene = modelViewer.scene
        viewerContent.renderer = modelViewer.renderer

        textureView.isOpaque = false
        viewerContent.renderer.clearOptions = modelViewer.renderer.clearOptions.apply {
            clear = true
        }

        viewerContent.scene.skybox = null
        viewerContent.view.blendMode = View.BlendMode.TRANSLUCENT

        textureView.setOnTouchListener { _, event ->
            modelViewer.onTouchEvent(event)
            true
        }

        choreographer.postFrameCallback(frameScheduler)

        (context as? Activity)?.registerActivityLifecycleCallbacks(object : Application.ActivityLifecycleCallbacks {
            override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {}
            override fun onActivityStarted(activity: Activity) {}
            override fun onActivityResumed(activity: Activity) {
                choreographer.postFrameCallback(frameScheduler)
            }
            override fun onActivityPaused(activity: Activity) {
                choreographer.removeFrameCallback(frameScheduler)
            }
            override fun onActivityStopped(activity: Activity) {}
            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}
            override fun onActivityDestroyed(activity: Activity) {
                choreographer.removeFrameCallback(frameScheduler)
                modelViewer.destroyModel()
            }
        })
    }

    /**
     * Loads a 3D model (GLB or GLTF).
     */
    fun setModel(buffer: ByteBuffer, fileName: String) {
        modelLoaded = false

        if (fileName.endsWith(".glb", ignoreCase = true)) {
            modelViewer.loadModelGlb(buffer)
            Log.d(TAG, "Loaded GLB model: $fileName")
        } else {
            Log.e(TAG, "Unsupported model format: $fileName")
            return
        }

        if (autoScaleEnabled) {
            modelViewer.transformToUnitCube()
        } else {
            modelViewer.clearRootTransform()
        }

        loadStartTime = System.nanoTime()
        loadStartFence = modelViewer.engine.createFence()
        modelLoaded = true
    }

    /**
     * Sets the lighting for the 3D scene.
     * @param skyBox The skybox data.
     * @param indirectLight The indirect light data.
     */
    fun setLights(indirectLight: ByteBuffer) {
        val engine = modelViewer.engine
        val scene = modelViewer.scene

        scene.indirectLight = KTX1Loader.createIndirectLight(engine, indirectLight)
        viewerContent.indirectLight = scene.indirectLight
        scene.indirectLight?.intensity = 25_000f
        Log.d(TAG, "Environment set: indirect light loaded")
    }

    /**
     * Configures the view options for rendering.
     */
    fun setViewOptions() {
        val view = modelViewer.view
        view.renderQuality = view.renderQuality.apply {
            hdrColorBuffer = View.QualityLevel.MEDIUM
        }
        view.dynamicResolutionOptions = view.dynamicResolutionOptions.apply {
            enabled = true
            quality = View.QualityLevel.MEDIUM
        }
        view.multiSampleAntiAliasingOptions = view.multiSampleAntiAliasingOptions.apply {
            enabled = true
        }
        view.antiAliasing = View.AntiAliasing.FXAA
        view.ambientOcclusionOptions = view.ambientOcclusionOptions.apply {
            enabled = true
        }
        view.bloomOptions = view.bloomOptions.apply {
            enabled = true
        }
        Log.d(TAG, "View options set")
    }

    /**
     * Destroys the 3D model and stops automation.
     */
    fun destroy() {
        modelViewer.destroyModel()
        Log.d(TAG, "ModelView destroyed")
    }

    private inner class FrameCallback : Choreographer.FrameCallback {
        private val startTime = System.nanoTime()

        override fun doFrame(frameTimeNanos: Long) {
            choreographer.postFrameCallback(this)

            loadStartFence?.let { fence ->
                val status = fence.wait(Fence.Mode.FLUSH, 0)
                if (status == Fence.FenceStatus.CONDITION_SATISFIED) {
                    val endTime = System.nanoTime()
                    val totalMs = (endTime - loadStartTime) / 1_000_000
                    Log.i(TAG, "Filament backend took $totalMs ms to load the model.")
                    modelViewer.engine.destroyFence(fence)
                    loadStartFence = null
                }
            }

            modelViewer.animator?.apply {
                if (animationCount > 0) {
                    val elapsedTimeSeconds = (frameTimeNanos - startTime) / 1_000_000_000.0
                    applyAnimation(0, elapsedTimeSeconds.toFloat())
                    updateBoneMatrices()
                }
            }

            try {
                modelViewer.render(frameTimeNanos)
            } catch (e: Exception) {
                Log.e(TAG, "Rendering exception: $e")
            }
        }
    }
}