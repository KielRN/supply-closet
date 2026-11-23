package app.supplycloset

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.sqrt

/** ARCore world distances and all persisted room coordinates are in metres. */
internal data class DoorVec(val x: Float, val y: Float, val z: Float) {
    operator fun plus(v: DoorVec) = DoorVec(x + v.x, y + v.y, z + v.z)
    operator fun minus(v: DoorVec) = DoorVec(x - v.x, y - v.y, z - v.z)
    operator fun times(k: Float) = DoorVec(x * k, y * k, z * k)
    fun dot(v: DoorVec) = x * v.x + y * v.y + z * v.z
    fun cross(v: DoorVec) = DoorVec(y * v.z - z * v.y, z * v.x - x * v.z, x * v.y - y * v.x)
    fun length() = sqrt(dot(this))
    fun unit() = this * (1f / length())
    fun array() = floatArrayOf(x, y, z)

    companion object {
        fun from(a: FloatArray) = DoorVec(a[0], a[1], a[2])
    }
}

internal data class SightLine(val eye: DoorVec, val direction: DoorVec) {
    /** Intersection of two independently observed rays. Pure camera rotation provides no depth. */
    fun intersect(other: SightLine): DoorVec? {
        val offset = other.eye - eye
        val cosine = direction.dot(other.direction)
        val sinSquared = 1f - cosine * cosine
        if (sinSquared < 0.0006f || offset.cross(direction).length() < 0.075f) return null
        val near = (offset.dot(direction) - cosine * offset.dot(other.direction)) / sinSquared
        val far = near * cosine - offset.dot(other.direction)
        if (near !in 0.25f..7f || far !in 0.25f..7f) return null
        val a = eye + direction * near
        val b = other.eye + other.direction * far
        return if ((a - b).length() <= 0.035f) (a + b) * 0.5f else null
    }
}

internal data class DoorBasis(val origin: DoorVec, val right: DoorVec, val inside: DoorVec, val width: Float) {
    fun world(local: DoorVec) = origin + right * local.x + DoorVec(0f, local.y, 0f) + inside * local.z
    fun local(world: DoorVec): DoorVec {
        val d = world - origin
        return DoorVec(d.dot(right), d.y, d.dot(inside))
    }

    fun matchesWidth(saved: Float?) = saved == null ||
        (saved.isFinite() && abs(width - saved) <= max(0.07f, saved * 0.075f).coerceAtMost(0.13f))

    companion object {
        fun from(left: DoorVec, right: DoorVec): DoorBasis? {
            val difference = right - left
            val horizontal = DoorVec(difference.x, 0f, difference.z)
            val width = horizontal.length()
            if (width !in 0.57f..2.5f || abs(difference.y) > 0.08f) return null
            val x = horizontal.unit()
            return DoorBasis((left + right) * 0.5f, x, DoorVec(-x.z, 0f, x.x), width)
        }
    }
}
