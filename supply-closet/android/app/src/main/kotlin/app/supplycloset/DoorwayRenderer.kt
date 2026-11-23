package app.supplycloset

import android.opengl.GLES11Ext.GL_TEXTURE_EXTERNAL_OES
import android.opengl.GLES20.*
import android.opengl.GLSurfaceView
import android.util.Log
import com.google.ar.core.Coordinates2d
import com.google.ar.core.Session
import com.google.ar.core.TrackingState
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

/** Composites the texture and projected points from the same ARCore frame into one GL surface. */
internal class DoorwayRenderer(
    private val density: Float,
    private val rotation: () -> Int,
    private val savedPoint: FloatArray?,
    private val savedWidth: Float?,
    private val status: (String, Boolean, Boolean) -> Unit,
    private val saved: (Pair<FloatArray, Float>) -> Unit,
    private val failure: (String) -> Unit,
) : GLSurfaceView.Renderer {
    @Volatile var session: Session? = null
    private val tracker = DoorTracker()
    private var width = 0
    private var height = 0
    private var appliedRotation = -1
    private var texture = 0
    private var boundSession: Session? = null
    private var cameraProgram = 0
    private var markerProgram = 0
    private var cameraPosition = 0
    private var cameraUv = 0
    private var markerPosition = 0
    private var markerType = 0
    private var confirmRequested = false
    private var saveRequested = false
    private var failed = false
    private var lastStatus: Triple<String, Boolean, Boolean>? = null
    private val quad = floats(8).apply { put(floatArrayOf(-1f, -1f, 1f, -1f, -1f, 1f, 1f, 1f)); rewind() }
    private val uv = floats(8)
    private var markers = floats(3 * 256)

    fun tap(x: Float, y: Float) = tracker.tap(x, y)
    fun confirm() { confirmRequested = true }
    fun save() { saveRequested = true }
    fun reset() {
        confirmRequested = false
        saveRequested = false
        tracker.reset()
    }
    fun close() = tracker.close()

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        try {
            boundSession = null
            cameraProgram = program(
                "attribute vec2 pos; attribute vec2 uv; varying vec2 tc; void main(){tc=uv; gl_Position=vec4(pos,0.,1.);}",
                "#extension GL_OES_EGL_image_external : require\nprecision mediump float; uniform samplerExternalOES cameraTex; varying vec2 tc; void main(){gl_FragColor=texture2D(cameraTex,tc);}"
            )
            markerProgram = program(MARKER_VERTEX, MARKER_FRAGMENT)
            cameraPosition = glGetAttribLocation(cameraProgram, "pos")
            cameraUv = glGetAttribLocation(cameraProgram, "uv")
            markerPosition = glGetAttribLocation(markerProgram, "pos")
            markerType = glGetAttribLocation(markerProgram, "kind")
            glUseProgram(markerProgram)
            glUniform1f(glGetUniformLocation(markerProgram, "density"), density)
            val ids = IntArray(1)
            glGenTextures(1, ids, 0)
            texture = ids[0]
            glBindTexture(GL_TEXTURE_EXTERNAL_OES, texture)
            glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
            glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
            glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
            glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)
        } catch (e: Exception) {
            fail(e)
        }
    }

    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        this.width = width
        this.height = height
        appliedRotation = -1
        glViewport(0, 0, width, height)
    }

    override fun onDrawFrame(gl: GL10?) {
        glClear(GL_COLOR_BUFFER_BIT)
        val active = session ?: return
        if (failed || width <= 0 || height <= 0) return
        try {
            if (boundSession !== active) {
                active.setCameraTextureName(texture)
                boundSession = active
                appliedRotation = -1
            }
            val displayRotation = rotation()
            if (appliedRotation != displayRotation) {
                active.setDisplayGeometry(displayRotation, width, height)
                appliedRotation = displayRotation
            }
            val frame = active.update()
            if (frame.timestamp == 0L) return
            quad.position(0)
            uv.position(0)
            frame.transformCoordinates2d(Coordinates2d.OPENGL_NORMALIZED_DEVICE_COORDINATES, quad,
                Coordinates2d.TEXTURE_NORMALIZED, uv)
            uv.position(0)
            quad.position(0)
            glUseProgram(cameraProgram)
            glActiveTexture(GL_TEXTURE0)
            glBindTexture(GL_TEXTURE_EXTERNAL_OES, texture)
            attribute(cameraPosition, 2, 0, quad)
            attribute(cameraUv, 2, 0, uv)
            glDrawArrays(GL_TRIANGLE_STRIP, 0, 4)
            glDisableVertexAttribArray(cameraPosition)
            glDisableVertexAttribArray(cameraUv)

            val overlay = tracker.update(frame, width, height, savedPoint, savedWidth)
            drawMarkers(overlay.points)
            val tracking = frame.camera.trackingState == TrackingState.TRACKING
            val canConfirm = tracking && overlay.canConfirm
            val canSave = tracking && savedPoint == null && overlay.canSave
            val next = Triple(overlay.message, canConfirm, canSave)
            if (lastStatus != next) {
                lastStatus = next
                status(next.first, next.second, next.third)
            }
            if (confirmRequested && canConfirm) tracker.confirm()
            if (saveRequested && canSave) tracker.save()?.let(saved)
            confirmRequested = false
            saveRequested = false
        } catch (e: Exception) {
            fail(e)
        }
    }

    private fun drawMarkers(points: List<FloatArray>) {
        if (points.isEmpty()) return
        if (markers.capacity() < points.size * 3) markers = floats(points.size * 3)
        markers.clear()
        // Rasterize the stable landmarks after the feature cloud, so nearby points never hide them.
        for (features in listOf(true, false)) {
            for (p in points) {
                if ((p[2] == 0f) == features) {
                    markers.put(2f * p[0] / width - 1f).put(1f - 2f * p[1] / height).put(p[2])
                }
            }
        }
        markers.flip()
        glUseProgram(markerProgram)
        attribute(markerPosition, 2, 12, markers)
        markers.position(2)
        attribute(markerType, 1, 12, markers)
        glDrawArrays(GL_POINTS, 0, points.size)
        glDisableVertexAttribArray(markerPosition)
        glDisableVertexAttribArray(markerType)
    }

    private fun fail(e: Exception) {
        if (failed) return
        failed = true
        Log.w("DoorwayAR", "AR rendering stopped", e)
        failure("The doorway camera stopped. Close other camera apps and try again.")
    }

    private fun floats(count: Int): FloatBuffer =
        ByteBuffer.allocateDirect(count * 4).order(ByteOrder.nativeOrder()).asFloatBuffer()

    private fun attribute(index: Int, size: Int, stride: Int, data: FloatBuffer) {
        glEnableVertexAttribArray(index)
        glVertexAttribPointer(index, size, GL_FLOAT, false, stride, data)
    }

    private fun program(vertex: String, fragment: String): Int {
        fun shader(type: Int, source: String): Int {
            val id = glCreateShader(type)
            glShaderSource(id, source)
            glCompileShader(id)
            val ok = IntArray(1)
            glGetShaderiv(id, GL_COMPILE_STATUS, ok, 0)
            check(ok[0] != 0) { glGetShaderInfoLog(id) }
            return id
        }
        val vs = shader(GL_VERTEX_SHADER, vertex)
        val fs = shader(GL_FRAGMENT_SHADER, fragment)
        val id = glCreateProgram()
        glAttachShader(id, vs)
        glAttachShader(id, fs)
        glLinkProgram(id)
        val ok = IntArray(1)
        glGetProgramiv(id, GL_LINK_STATUS, ok, 0)
        check(ok[0] != 0) { glGetProgramInfoLog(id) }
        glDeleteShader(vs)
        glDeleteShader(fs)
        return id
    }

    companion object {
        private const val MARKER_VERTEX = """
            attribute vec2 pos;
            attribute float kind;
            uniform float density;
            varying float k;
            void main() {
                k = kind;
                gl_Position = vec4(pos, 0., 1.);
                gl_PointSize = density * (kind < 0.5 ? 4. : (kind == 3. ? 34. : 23.));
            }
        """
        private const val MARKER_FRAGMENT = """
            precision mediump float;
            varying float k;
            void main() {
                vec2 q = gl_PointCoord * 2. - 1.;
                float r = length(q);
                if (r > 1.) discard;
                vec3 dark = vec3(0.04, 0.12, 0.16);
                vec3 color = k < 0.5 ? vec3(0.55, 1., 0.92) :
                    (k > 3.5 ? vec3(1., 0.76, 0.23) : (k == 3. ? vec3(0.40, 1., 0.65) : vec3(0.22, 0.91, 1.)));
                if (k > 0.5 && r < 0.63) {
                    if (k == 3. && min(abs(q.x),abs(q.y)) < 0.06) color = dark;
                    else if (r > 0.51) color = dark;
                    else discard;
                }
                gl_FragColor = vec4(r > 0.86 ? dark : color, 1.);
            }
        """
    }
}
