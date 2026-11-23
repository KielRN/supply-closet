package app.supplycloset

import org.junit.Assert.*
import org.junit.Test

class DoorGeometryTest {
    @Test fun reopeningFromADifferentSessionRestoresTheSameBin() {
        val first = DoorBasis.from(DoorVec(-0.5f, 2f, 0f), DoorVec(0.5f, 2f, 0f))!!
        val second = DoorBasis.from(DoorVec(4f, 3f, 7.5f), DoorVec(4f, 3f, 6.5f))!!
        val saved = first.local(DoorVec(1.25f, 1.5f, 3f))
        assertArrayEquals(floatArrayOf(1.25f, -0.5f, 3f), saved.array(), 0.001f)
        assertArrayEquals(floatArrayOf(7f, 2.5f, 5.75f), second.world(saved).array(), 0.001f)
        assertTrue(second.matchesWidth(first.width))
        assertFalse(second.matchesWidth(1.4f))
    }

    @Test fun triangulationNeedsLateralMotionAndConsistentRays() {
        val target = DoorVec(0.5f, 1.5f, -2f)
        fun ray(eye: DoorVec, aim: DoorVec) = SightLine(eye, (aim - eye).unit())
        val a = ray(DoorVec(0f, 1f, 0f), target)
        val b = ray(DoorVec(0.3f, 1f, 0f), target)
        assertArrayEquals(target.array(), a.intersect(b)!!.array(), 0.001f)
        assertNull(a.intersect(a))
        assertNull(a.intersect(ray(b.eye, target + DoorVec(0f, 0.4f, 0f))))
    }
}
