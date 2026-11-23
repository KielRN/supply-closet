package app.supplycloset

import android.opengl.Matrix
import com.google.ar.core.Anchor
import com.google.ar.core.Coordinates2d
import com.google.ar.core.DepthPoint
import com.google.ar.core.Frame
import com.google.ar.core.HitResult
import com.google.ar.core.Plane
import com.google.ar.core.Point
import com.google.ar.core.Pose
import com.google.ar.core.TrackingState
import com.google.ar.core.exceptions.NotTrackingException
import com.google.ar.core.exceptions.NotYetAvailableException
import com.google.ar.core.exceptions.ResourceExhaustedException
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

data class DoorOverlay(val message: String, val points: List<FloatArray>, val canConfirm: Boolean, val canSave: Boolean)

private data class Pixel(val x: Float, val y: Float) {
    fun distanceSquared(p: Pixel): Float = (x - p.x) * (x - p.x) + (y - p.y) * (y - p.y)
}

private class ViewGeometry(frame: Frame, val width: Int, val height: Int) {
    val eye = DoorVec.from(frame.camera.pose.translation)
    private val vp = FloatArray(16)
    private val inverse = FloatArray(16)
    private val valid: Boolean

    init {
        val view = FloatArray(16)
        val projection = FloatArray(16)
        frame.camera.getViewMatrix(view, 0)
        frame.camera.getProjectionMatrix(projection, 0, 0.05f, 30f)
        Matrix.multiplyMM(vp, 0, projection, 0, view, 0)
        valid = Matrix.invertM(inverse, 0, vp, 0)
    }

    fun project(p: DoorVec): Pixel? {
        val w = vp[3] * p.x + vp[7] * p.y + vp[11] * p.z + vp[15]
        if (w <= 0.05f || !valid) return null
        val x = (vp[0] * p.x + vp[4] * p.y + vp[8] * p.z + vp[12]) / w
        val y = (vp[1] * p.x + vp[5] * p.y + vp[9] * p.z + vp[13]) / w
        if (abs(x) > 1f || abs(y) > 1f) return null
        return Pixel((x + 1f) * width / 2f, (1f - y) * height / 2f)
    }

    fun ray(p: Pixel): SightLine? {
        if (!valid || p.x !in 0f..width.toFloat() || p.y !in 0f..height.toFloat()) return null
        val near = FloatArray(4)
        val clip = floatArrayOf(2f * p.x / width - 1f, 1f - 2f * p.y / height, -1f, 1f)
        Matrix.multiplyMV(near, 0, inverse, 0, clip, 0)
        if (abs(near[3]) < 0.00001f) return null
        val direction = DoorVec.from(near) * (1f / near[3]) - eye
        return SightLine(eye, direction.unit())
    }
}

private data class ImageCorner(val pixel: Pixel, val score: Int)

/** Finds an upright lintel with two descending jamb edges in a small luminance copy of this view. */
private class DoorEdges(private val cells: IntArray, val cols: Int, val rows: Int, val w: Int, val h: Int) {
    val candidates = Array(2) { mutableListOf<ImageCorner>() }
    var pair: Pair<Pixel, Pixel>? = null
        private set

    private fun edgeX(x: Int, y: Int) = abs(cells[y * cols + x + 1] - cells[y * cols + x - 1])
    private fun edgeY(x: Int, y: Int) = abs(cells[(y + 1) * cols + x] - cells[(y - 1) * cols + x])
    private fun upright(x: Int, y: Int) = max(edgeX(x, y), max(edgeX(x - 1, y), edgeX(x + 1, y)))
    private fun across(x: Int, y: Int) = max(edgeY(x, y), max(edgeY(x, y - 1), edgeY(x, y + 1)))
    private fun col(p: Pixel) = (p.x * cols / w - 0.5f).roundToInt()
    private fun row(p: Pixel) = (p.y * rows / h - 0.5f).roundToInt()

    init {
        val low = 13
        val endY = min(rows - 10, rows * 85 / 100)
        for (y in 3 until endY) {
            for (x in 10 until cols - 10) {
                if (upright(x, y + 2) < low || upright(x, y + 5) < low || upright(x, y + 8) < low) continue
                for (side in 0..1) {
                    val sign = if (side == 0) 1 else -1
                    val a = across(x + 2 * sign, y)
                    val b = across(x + 5 * sign, y)
                    val c = across(x + 8 * sign, y)
                    if (min(a, min(b, c)) < low) continue
                    val vertical = upright(x, y + 3) + upright(x, y + 6)
                    val score = min(vertical, a + b) + min(a, c) + edgeX(x, y + 2) + edgeY(x + 2 * sign, y)
                    candidates[side].add(ImageCorner(Pixel((x + 0.5f) * w / cols, (y + 0.5f) * h / rows), score))
                }
            }
        }
        // Suppress repeated responses around one corner before matching doorway pairs.
        for (side in 0..1) {
            val sorted = candidates[side].sortedByDescending { it.score }
            candidates[side].clear()
            val spacing = 3f * w / cols
            for (corner in sorted) {
                if (candidates[side].none { it.pixel.distanceSquared(corner.pixel) < spacing * spacing }) {
                    candidates[side].add(corner)
                    if (candidates[side].size == 80) break
                }
            }
        }
        var best = 0f
        for (left in candidates[0]) for (right in candidates[1]) {
            val x0 = col(left.pixel)
            val y0 = row(left.pixel)
            val dx = col(right.pixel) - x0
            val dy = row(right.pixel) - y0
            if (dx !in cols / 6..cols * 9 / 10 || abs(dy) > dx * 0.18f) continue
            var supported = 0
            for (k in 1..9) {
                if (across(x0 + dx * k / 10, y0 + (dy * k / 10f).roundToInt()) >= low) supported++
            }
            if (supported < 7) continue
            val score = min(left.score, right.score) + 12f * supported + dx * 0.5f
            if (score > best) {
                best = score
                pair = left.pixel to right.pixel
            }
        }
    }

    fun nearby(side: Int, target: Pixel, radius: Float): Pixel? =
        candidates[side].filter { it.pixel.distanceSquared(target) <= radius * radius }
            .minByOrNull { it.pixel.distanceSquared(target) }?.pixel

    companion object {
        fun read(frame: Frame, view: ViewGeometry): DoorEdges? = try {
            frame.acquireCameraImage().use { image ->
                val scale = 160f / max(view.width, view.height)
                val cols = (view.width * scale).roundToInt().coerceAtLeast(40)
                val rows = (view.height * scale).roundToInt().coerceAtLeast(40)
                val imageTriangle = FloatArray(6)
                frame.transformCoordinates2d(Coordinates2d.VIEW_NORMALIZED, floatArrayOf(0f, 0f, 1f, 0f, 0f, 1f),
                    Coordinates2d.IMAGE_PIXELS, imageTriangle)
                val plane = image.planes[0]
                val buffer = plane.buffer
                val stride = plane.rowStride
                val pixelStride = plane.pixelStride
                val data = IntArray(cols * rows)
                for (y in 0 until rows) for (x in 0 until cols) {
                    val u = (x + 0.5f) / cols
                    val v = (y + 0.5f) / rows
                    val ix = (imageTriangle[0] + u * (imageTriangle[2] - imageTriangle[0]) +
                        v * (imageTriangle[4] - imageTriangle[0])).toInt().coerceIn(0, image.width - 1)
                    val iy = (imageTriangle[1] + u * (imageTriangle[3] - imageTriangle[1]) +
                        v * (imageTriangle[5] - imageTriangle[1])).toInt().coerceIn(0, image.height - 1)
                    data[y * cols + x] = buffer.get(iy * stride + ix * pixelStride).toInt() and 255
                }
                DoorEdges(data, cols, rows, view.width, view.height)
            }
        } catch (_: NotYetAvailableException) {
            null
        } catch (_: ResourceExhaustedException) {
            null
        }
    }
}

private data class Surface(val hit: HitResult, val depth: Float)
private data class FirstCorner(val ray: SightLine, val seed: DoorVec)
private class CornerState {
    var first: FirstCorner? = null
    var intersection: DoorVec? = null
    var anchor: Anchor? = null
    fun position() = anchor?.pose?.translation?.let(DoorVec::from) ?: first?.seed
    fun clear() {
        anchor?.detach()
        anchor = null
        first = null
        intersection = null
    }
}

class DoorTracker {
    private val corners = Array(2) { CornerState() }
    private var aligned = false
    private var allowConfirm = false
    private var manual = false
    private var pendingTap: Pixel? = null
    private var lastSample = 0L
    private var bin: Anchor? = null
    private var binEye: DoorVec? = null
    private var binChecks = 0
    private var validBin = false
    private var currentSave: Pair<FloatArray, Float>? = null
    private var startupMessage = "Inside the room, face the doorway. Keep both upper opening corners visible."

    fun tap(x: Float, y: Float) { pendingTap = Pixel(x, y) }
    fun confirm() {
        if (allowConfirm) {
            aligned = true
            allowConfirm = false
        }
    }
    fun save() = currentSave?.let { it.first.copyOf() to it.second }
    fun reset() {
        corners.forEach { it.clear() }
        clearBin()
        manual = false
        aligned = false
        allowConfirm = false
        pendingTap = null
        lastSample = 0L
        startupMessage = "Inside the room, face the doorway. Keep both upper opening corners visible."
    }
    fun close() = reset()
    private fun clearBin() {
        bin?.detach()
        bin = null
        binEye = null
        binChecks = 0
        validBin = false
        currentSave = null
    }

    private fun hits(frame: Frame, p: Pixel, jamb: Boolean): List<HitResult> =
        frame.hitTest(p.x, p.y).filter { hit ->
            val trackable = hit.trackable
            hit.distance in 0.20f..8f && trackable.trackingState == TrackingState.TRACKING &&
                when (trackable) {
                    is Plane -> (!jamb || trackable.type == Plane.Type.VERTICAL) && trackable.isPoseInPolygon(hit.hitPose)
                    is DepthPoint -> true
                    is Point -> true
                    else -> false
                }
        }

    private fun jambSurface(frame: Frame, view: ViewGeometry, p: Pixel, side: Int, ray: SightLine): Surface? {
        // Probe the solid frame above/outside the opening. An exact silhouette hit may be the far wall.
        val step = min(view.width, view.height) * 0.014f
        val out = if (side == 0) -step else step
        val probes = listOf(Pixel(p.x + out, p.y - step), Pixel(p.x, p.y - step), Pixel(p.x + out, p.y), p)
        return probes.filter { view.ray(it) != null }.mapNotNull { q ->
            hits(frame, q, true).firstOrNull()?.let {
                val offset = DoorVec.from(it.hitPose.translation) - ray.eye
                Surface(it, offset.dot(ray.direction))
            }
        }.filter { it.depth in 0.25f..7f }.minByOrNull { it.depth }
    }

    private fun makeAnchor(hit: HitResult, world: DoorVec): Anchor? = try {
        hit.trackable.createAnchor(Pose.makeTranslation(world.x, world.y, world.z))
    } catch (_: NotTrackingException) {
        null
    } catch (_: ResourceExhaustedException) {
        null
    }

    private fun observe(frame: Frame, view: ViewGeometry, side: Int, pixel: Pixel) {
        val corner = corners[side]
        if (corner.anchor != null) return
        val ray = view.ray(pixel) ?: return
        val surface = jambSurface(frame, view, pixel, side, ray) ?: return
        val measured = ray.eye + ray.direction * surface.depth
        val first = corner.first
        if (first == null) {
            corner.first = FirstCorner(ray, measured)
            return
        }
        val at = first.ray.intersect(ray) ?: return
        // Triangulation uses current image edges (or a fresh manual tap), never projected predictions alone.
        // The support distance must agree in both views, which rejects points behind an open doorway.
        if ((at - measured).length() > 0.12f || (at - first.seed).length() > 0.12f) return
        val previous = corner.intersection
        if (previous != null && (at - previous).length() < 0.06f) {
            corner.anchor = makeAnchor(surface.hit, (at + previous) * 0.5f)
        }
        corner.intersection = at
    }

    private fun manualSide(view: ViewGeometry, p: Pixel): Int {
        val locations = corners.map { it.position()?.let(view::project) }
        val nearest = locations.indices.filter { locations[it] != null }.minByOrNull { locations[it]!!.distanceSquared(p) }
        if (nearest != null && locations[nearest]!!.distanceSquared(p) < (view.width * 0.16f) * (view.width * 0.16f)) return nearest
        return corners.indexOfFirst { it.first == null }.takeIf { it >= 0 } ?: nearest ?: 0
    }

    private fun sampleCorners(frame: Frame, view: ViewGeometry, tap: Pixel?) {
        val edges = DoorEdges.read(frame, view)
        if (tap != null) {
            manual = true
            val side = manualSide(view, tap)
            val old = corners[side].position()?.let(view::project)
            val pixel = edges?.nearby(side, tap, min(view.width, view.height) * 0.025f) ?: tap
            val radius = min(view.width, view.height) * 0.032f
            if (old == null || old.distanceSquared(pixel) > radius * radius || corners[side].anchor != null) corners[side].clear()
            observe(frame, view, side, pixel)
            return
        }
        for (side in 0..1) {
            if (corners[side].anchor != null) continue
            val old = corners[side].position()
            val pixel = if (old != null) {
                view.project(old)?.let { edges?.nearby(side, it, min(view.width, view.height) * 0.045f) }
            } else if (!manual && edges?.pair != null) {
                if (side == 0) edges.pair!!.first else edges.pair!!.second
            } else null
            if (pixel != null) observe(frame, view, side, pixel)
        }
    }

    private fun sampleBin(frame: Frame, view: ViewGeometry, room: DoorBasis, tap: Pixel?) {
        if (tap != null) {
            clearBin()
            val hit = hits(frame, tap, false).firstOrNull() ?: return
            val pos = DoorVec.from(hit.hitPose.translation)
            if (room.local(pos).z < -0.12f) return
            bin = makeAnchor(hit, pos)
            binEye = view.eye
            return
        }
        if (validBin) return
        val pos = bin?.pose?.translation?.let(DoorVec::from) ?: return
        val start = binEye ?: return
        val p = view.project(pos) ?: return
        val ray = view.ray(p) ?: return
        if ((view.eye - start).cross(ray.direction).length() < 0.055f) return
        val hit = hits(frame, p, false).firstOrNull() ?: return
        if ((DoorVec.from(hit.hitPose.translation) - pos).length() > 0.065f) {
            binChecks = 0
            return
        }
        binChecks++
        validBin = binChecks >= 2
    }

    fun update(frame: Frame, width: Int, height: Int, savedPoint: FloatArray?, savedWidth: Float?): DoorOverlay {
        if (frame.camera.trackingState != TrackingState.TRACKING || width <= 0 || height <= 0 ||
            corners.any { it.anchor != null && it.anchor?.trackingState != TrackingState.TRACKING }) {
            reset()
            startupMessage = "Tracking paused. Move slowly, then face the same doorway from inside and align again."
            return DoorOverlay(startupMessage, emptyList(), false, false)
        }
        val view = ViewGeometry(frame, width, height)
        val dots = mutableListOf<FloatArray>()
        fun mark(pixel: Pixel?, type: Int) {
            if (pixel != null) dots.add(floatArrayOf(pixel.x, pixel.y, type.toFloat()))
        }
        try {
            frame.acquirePointCloud().use { cloud ->
                val values = cloud.points
                val stride = max(1, values.remaining() / (4 * 140)) * 4
                var i = values.position()
                while (i + 3 < values.limit()) {
                    if (values[i + 3] >= 0.45f) mark(view.project(DoorVec(values[i], values[i + 1], values[i + 2])), 0)
                    i += stride
                }
            }
        } catch (_: NotYetAvailableException) {
            // ARCore may track the camera before a point cloud becomes available.
        }
        val tap = pendingTap
        pendingTap = null
        val sample = tap != null || frame.timestamp - lastSample >= 200_000_000L
        if (sample) {
            lastSample = frame.timestamp
            if (!aligned) sampleCorners(frame, view, tap)
        }
        val positions = corners.map { it.position() }
        val pixels = positions.map { it?.let(view::project) }
        for (side in 0..1) mark(pixels[side], (if (corners[side].anchor == null) 4 else 1) + side)
        val both = corners.all { it.anchor != null }
        val room = if (both) DoorBasis.from(positions[0]!!, positions[1]!!) else null
        val widthMatch = room?.matchesWidth(savedWidth) == true
        val left = pixels[0]
        val right = pixels[1]
        val order = left != null && right != null && left.x < right.x
        val inside = room != null && room.local(view.eye).z > 0.20f
        allowConfirm = !aligned && widthMatch && inside && order
        currentSave = null
        if (aligned && (!widthMatch || room == null)) {
            reset()
            return DoorOverlay("Doorway measurements changed. Align the two upper corners again.", emptyList(), false, false)
        }
        if (aligned && room != null) {
            if (bin != null && bin?.trackingState != TrackingState.TRACKING) clearBin()
            if (sample && savedPoint == null) sampleBin(frame, view, room, tap)
            val target = bin?.pose?.translation?.let(DoorVec::from)
            val restored = savedPoint?.takeIf { it.size == 3 && it.all(Float::isFinite) }?.let(DoorVec::from)
            val actual = target ?: restored?.let(room::world)
            val onScreen = actual?.let(view::project)
            mark(onScreen, 3)
            if (target != null && validBin) currentSave = room.local(target).array() to room.width
            val message = when {
                target != null && !validBin -> "Keep the bin in view and move slightly sideways to verify its surface."
                target != null -> "Bin position measured. Save it or tap another bin surface."
                restored != null && onScreen == null -> "Doorway aligned. Turn toward the saved bin."
                restored != null -> "Doorway aligned. The marker shows the saved bin position."
                tap != null -> "No measured bin surface here. Move slowly and tap the front of the bin again."
                else -> "Doorway aligned. Face the bin and tap its front surface."
            }
            return DoorOverlay(message, dots, false, currentSave != null)
        }
        val message = when {
            both && room == null -> "Corners must be level and span the opening. Tap either upper corner to correct it."
            both && !widthMatch -> "Width differs from the saved doorway. Check the room and reselect its corners."
            both && !allowConfirm -> "Face both upper corners from inside the room, with left and right in view."
            allowConfirm -> "Check the markers on the upper opening corners, then confirm the doorway."
            manual && corners[0].first == null -> "Tap the upper-left opening corner on the solid door frame."
            manual && corners[1].first == null -> "Tap the upper-right opening corner on the solid door frame."
            corners.any { it.first != null } -> "Move sideways 10–20 cm, keeping the corners visible. Tap a misplaced corner to correct it."
            else -> "$startupMessage You can also tap the upper-left corner, then the right."
        }
        return DoorOverlay(message, dots, allowConfirm, false)
    }
}
