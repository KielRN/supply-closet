package app.supplycloset

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.opengl.GLSurfaceView
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import com.google.ar.core.ArCoreApk
import com.google.ar.core.Config
import com.google.ar.core.Session
import com.google.ar.core.exceptions.*
import kotlin.math.roundToInt

class DoorwayActivity : Activity() {
    private lateinit var surface: GLSurfaceView
    private lateinit var renderer: DoorwayRenderer
    private lateinit var instructions: TextView
    private lateinit var confirm: Button
    private lateinit var save: Button
    private var session: Session? = null
    private var resumed = false
    private var running = false
    private var askedToInstall = false
    private var permissionPending = false
    private var availabilityRetries = 0
    private val handler = Handler(Looper.getMainLooper())
    private val checkAgain = Runnable { startCamera() }

    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        askedToInstall = state?.getBoolean("askedToInstall") ?: false
        setResult(RESULT_CANCELED, Intent().putExtra("status", "cancelled"))
        val point = intent.getFloatArrayExtra("point")
        val width = if (intent.hasExtra("width")) intent.getFloatExtra("width", 0f) else null
        renderer = DoorwayRenderer(resources.displayMetrics.density, { windowManager.defaultDisplay.rotation },
            point, width, { message, canConfirm, canSave ->
                runOnUiThread {
                    if (running && !isFinishing) {
                        instructions.text = message
                        confirm.visibility = if (canConfirm) View.VISIBLE else View.GONE
                        save.visibility = if (canSave) View.VISIBLE else View.GONE
                    }
                }
            }, { (position, measuredWidth) ->
                runOnUiThread {
                    if (!isFinishing && resumed) {
                        setResult(RESULT_OK, Intent().putExtra("status", "saved")
                            .putExtra("point", position).putExtra("width", measuredWidth))
                        finish()
                    }
                }
            }, { message -> runOnUiThread { finishWith("error", message) } })
        buildView()
    }

    private fun buildView() {
        val root = FrameLayout(this)
        root.setBackgroundColor(Color.BLACK)
        root.setOnApplyWindowInsetsListener { v, insets ->
            v.setPadding(insets.systemWindowInsetLeft, insets.systemWindowInsetTop,
                insets.systemWindowInsetRight, insets.systemWindowInsetBottom)
            insets
        }
        surface = GLSurfaceView(this).apply {
            setEGLContextClientVersion(2)
            preserveEGLContextOnPause = true
            setRenderer(renderer)
            setOnTouchListener { _, e ->
                if (e.actionMasked == MotionEvent.ACTION_UP && running) {
                    val x = e.x
                    val y = e.y
                    queueEvent { renderer.tap(x, y) }
                    performClick()
                }
                true
            }
        }
        root.addView(surface, FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))

        val header = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(8), dp(16), dp(8))
            setBackgroundColor(Color.argb(225, 17, 32, 42))
        }
        header.addView(text(intent.getStringExtra("roomName").orEmpty(), 18f))
        val label = intent.getStringExtra("label").orEmpty()
        if (label.isNotBlank()) header.addView(text(label, 18f))
        root.addView(header, FrameLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT, Gravity.TOP))

        val footer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(12), dp(10), dp(12), dp(6))
            setBackgroundColor(Color.argb(240, 17, 32, 42))
        }
        instructions = text("Checking doorway tracking support…", 18f)
        footer.addView(instructions)
        val buttons = LinearLayout(this).apply { gravity = Gravity.START }
        fun button(label: String, action: () -> Unit): Button {
            return Button(this).apply {
                text = label
                isAllCaps = false
                minHeight = dp(48)
                minWidth = dp(48)
                setOnClickListener { action() }
                buttons.addView(this)
            }
        }
        button("Close") { finish() }
        button("Reset") { if (running) surface.queueEvent { renderer.reset() } }
        confirm = button("Confirm") { surface.queueEvent { renderer.confirm() } }
        save = button("Save bin") { surface.queueEvent { renderer.save() } }
        confirm.visibility = View.GONE
        save.visibility = View.GONE
        footer.addView(buttons)
        root.addView(footer, FrameLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT, Gravity.BOTTOM))
        setContentView(root)
    }

    private fun text(value: String, size: Float) = TextView(this).apply {
        text = value
        textSize = size
        setTextColor(Color.WHITE)
    }

    private fun dp(value: Int) = (value * resources.displayMetrics.density).roundToInt()

    override fun onResume() {
        super.onResume()
        resumed = true
        availabilityRetries = 0
        startCamera()
    }

    private fun startCamera() {
        if (!resumed || running || isFinishing || permissionPending) return
        try {
            if (session == null) {
                val apk = ArCoreApk.getInstance()
                val availability = apk.checkAvailability(this)
                if (availability.isTransient && availabilityRetries++ < 40) {
                    handler.postDelayed(checkAgain, 250)
                    return
                }
                if (availability.isUnsupported) {
                    finishWith("unavailable", "This phone does not support ARCore doorway tracking.")
                    return
                }
                if (!availability.isSupported) {
                    finishWith("error", "Google Play Services for AR could not verify support. Check your connection and retry.")
                    return
                }
                if (apk.requestInstall(this, !askedToInstall) == ArCoreApk.InstallStatus.INSTALL_REQUESTED) {
                    askedToInstall = true
                    return
                }
                if (checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
                    permissionPending = true
                    requestPermissions(arrayOf(Manifest.permission.CAMERA), CAMERA_PERMISSION)
                    return
                }
                val newSession = Session(this)
                session = newSession
                newSession.configure(Config(newSession).apply {
                    focusMode = Config.FocusMode.AUTO
                    planeFindingMode = Config.PlaneFindingMode.HORIZONTAL_AND_VERTICAL
                    if (newSession.isDepthModeSupported(Config.DepthMode.AUTOMATIC)) depthMode = Config.DepthMode.AUTOMATIC
                })
            }
            val active = session ?: return
            active.resume()
            running = true
            renderer.session = active
            surface.onResume()
        } catch (e: Exception) {
            val message = when (e) {
                is UnavailableDeviceNotCompatibleException -> "This phone does not support ARCore doorway tracking."
                is UnavailableUserDeclinedInstallationException -> "Install Google Play Services for AR to use doorway tracking."
                is UnavailableApkTooOldException, is UnavailableArcoreNotInstalledException ->
                    "Install or update Google Play Services for AR to use doorway tracking."
                is UnavailableSdkTooOldException -> "Update SupplyCloset to use this version of Google Play Services for AR."
                is CameraNotAvailableException -> "The camera is busy. Close other camera apps and try again."
                is SecurityException -> "Enable camera access in Android settings to use doorway tracking."
                else -> "The ARCore doorway session could not start. Try again."
            }
            finishWith(if (e is UnavailableDeviceNotCompatibleException) "unavailable" else "error", message)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != CAMERA_PERMISSION) return
        permissionPending = false
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) startCamera()
        else finishWith("error", "Camera permission is needed for doorway tracking. You can enable it in Android settings.")
    }

    override fun onSaveInstanceState(state: Bundle) {
        super.onSaveInstanceState(state)
        state.putBoolean("askedToInstall", askedToInstall)
    }

    override fun onPause() {
        resumed = false
        handler.removeCallbacks(checkAgain)
        renderer.session = null
        if (isFinishing) surface.queueEvent { renderer.close() }
        surface.onPause() // Wait for frame processing before pausing the session.
        if (running) session?.pause()
        running = false
        super.onPause()
    }

    override fun onDestroy() {
        val released = session
        session = null
        // Closing a paused native session may block for several seconds.
        if (released != null) Thread { released.close() }.start()
        super.onDestroy()
    }

    private fun finishWith(status: String, message: String) {
        if (isFinishing) return
        setResult(RESULT_OK, Intent().putExtra("status", status).putExtra("message", message))
        finish()
    }

    companion object {
        private const val CAMERA_PERMISSION = 6703
    }
}
