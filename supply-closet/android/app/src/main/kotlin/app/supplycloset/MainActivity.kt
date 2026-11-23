package app.supplycloset

import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs
import kotlin.math.sqrt

class MainActivity : FlutterActivity(), SensorEventListener {
    private var sensorManager: SensorManager? = null
    private var rotationSensor: Sensor? = null
    private var gyroSensor: Sensor? = null
    private var eventSink: EventChannel.EventSink? = null
    private var doorwayResult: MethodChannel.Result? = null

    private val rotationMatrix = FloatArray(9)
    private val remappedMatrix = FloatArray(9)
    private val orientationAngles = FloatArray(3)

    private var baseYawDeg: Double? = null
    private var lastYawDeg: Double = 0.0
    private var lastPitchDeg: Double = 0.0
    private var angularSpeedDegPerSec: Double = 0.0
    private var lastTimestampNs: Long = 0L

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        sensorManager = getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        rotationSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_GAME_ROTATION_VECTOR)
            ?: sensorManager?.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
        gyroSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_GYROSCOPE)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.supplycloset/doorway")
            .setMethodCallHandler { call, result ->
                if (call.method != "scan") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (doorwayResult != null) {
                    result.success(mapOf("status" to "error", "message" to "A doorway scan is already open."))
                    return@setMethodCallHandler
                }
                val mode = call.argument<String>("mode")
                val coords = call.argument<List<*>>("point")?.mapNotNull { (it as? Number)?.toFloat() }
                val width = call.argument<Number>("width")?.toFloat()
                if (mode !in listOf("place", "find") || mode == "find" &&
                    (coords?.size != 3 || coords.any { !it.isFinite() } || width == null || !width.isFinite() || width <= 0)) {
                    result.success(mapOf("status" to "error", "message" to "The saved doorway location is incomplete."))
                    return@setMethodCallHandler
                }
                val scanner = Intent(this, DoorwayActivity::class.java)
                    .putExtra("mode", mode)
                    .putExtra("roomName", call.argument<String>("roomName"))
                    .putExtra("label", call.argument<String>("label"))
                if (width != null && (!width.isFinite() || width <= 0)) {
                    result.success(mapOf("status" to "error", "message" to "Invalid saved doorway width."))
                    return@setMethodCallHandler
                }
                if (mode == "find") scanner.putExtra("point", coords!!.toFloatArray())
                if (width != null) scanner.putExtra("width", width)
                doorwayResult = result
                try {
                    startActivityForResult(scanner, DOORWAY_REQUEST)
                } catch (e: RuntimeException) {
                    doorwayResult = null
                    result.success(mapOf("status" to "error", "message" to "The doorway camera could not open."))
                }
            }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app.supplycloset/spatial_sensors"
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                baseYawDeg = null
                lastTimestampNs = 0L
                startSensors()
            }

            override fun onCancel(arguments: Any?) {
                stopSensors()
                eventSink = null
            }
        })

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app.supplycloset/spatial_control"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "recenterOrigin" -> {
                    baseYawDeg = null
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startSensors() {
        val sm = sensorManager ?: return
        rotationSensor?.let {
            sm.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
        }
        gyroSensor?.let {
            sm.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
        }
    }

    @Deprecated("Kept for compatibility with FlutterActivity's plugin result dispatch")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != DOORWAY_REQUEST) return
        val result = doorwayResult ?: return
        doorwayResult = null
        val response = mutableMapOf<String, Any>("status" to (data?.getStringExtra("status") ?: "cancelled"))
        data?.getStringExtra("message")?.let { response["message"] = it }
        data?.getFloatArrayExtra("point")?.let { response["point"] = it.map(Float::toDouble) }
        if (data?.hasExtra("width") == true) response["width"] = data.getFloatExtra("width", 0f).toDouble()
        result.success(response)
    }

    companion object {
        private const val DOORWAY_REQUEST = 6702
    }

    private fun stopSensors() {
        sensorManager?.unregisterListener(this)
    }

    override fun onSensorChanged(event: SensorEvent?) {
        val ev = event ?: return
        val sink = eventSink ?: return

        if (ev.sensor.type == Sensor.TYPE_GYROSCOPE) {
            val gx = ev.values[0].toDouble()
            val gy = ev.values[1].toDouble()
            val gz = ev.values[2].toDouble()
            val radPerSec = sqrt(gx * gx + gy * gy + gz * gz)
            angularSpeedDegPerSec = Math.toDegrees(radPerSec)

            // Fallback integration if rotation vector sensor is absent
            if (rotationSensor == null) {
                if (lastTimestampNs != 0L) {
                    val dt = (ev.timestamp - lastTimestampNs) * 1e-9
                    if (dt in 0.0001..0.5) {
                        lastYawDeg = normalizeAngleDeg(lastYawDeg - Math.toDegrees(gy) * dt)
                        lastPitchDeg = (lastPitchDeg + Math.toDegrees(gx) * dt).coerceIn(-65.0, 65.0)
                        sink.success(
                            mapOf(
                                "yawDeg" to lastYawDeg,
                                "pitchDeg" to lastPitchDeg,
                                "rollDeg" to 0.0,
                                "angularSpeed" to angularSpeedDegPerSec
                            )
                        )
                    }
                }
                lastTimestampNs = ev.timestamp
            }
            return
        }

        if (ev.sensor.type == Sensor.TYPE_GAME_ROTATION_VECTOR ||
            ev.sensor.type == Sensor.TYPE_ROTATION_VECTOR
        ) {
            SensorManager.getRotationMatrixFromVector(rotationMatrix, ev.values)
            // Remap for upright portrait phone looking through back camera
            SensorManager.remapCoordinateSystem(
                rotationMatrix,
                SensorManager.AXIS_X,
                SensorManager.AXIS_Z,
                remappedMatrix
            )
            SensorManager.getOrientation(remappedMatrix, orientationAngles)

            val rawAzimuthDeg = Math.toDegrees(orientationAngles[0].toDouble())
            val rawPitchDeg = -Math.toDegrees(orientationAngles[1].toDouble())
            val rawRollDeg = Math.toDegrees(orientationAngles[2].toDouble())

            if (baseYawDeg == null) {
                baseYawDeg = rawAzimuthDeg
            }
            val relYaw = normalizeAngleDeg(rawAzimuthDeg - (baseYawDeg ?: 0.0))

            if (gyroSensor == null && lastTimestampNs != 0L) {
                val dt = (ev.timestamp - lastTimestampNs) * 1e-9
                if (dt in 0.001..0.5) {
                    val dYaw = normalizeAngleDeg(relYaw - lastYawDeg)
                    val dPitch = rawPitchDeg - lastPitchDeg
                    angularSpeedDegPerSec = sqrt(dYaw * dYaw + dPitch * dPitch) / dt
                }
            }
            lastTimestampNs = ev.timestamp
            lastYawDeg = relYaw
            lastPitchDeg = rawPitchDeg.coerceIn(-65.0, 65.0)

            sink.success(
                mapOf(
                    "yawDeg" to lastYawDeg,
                    "pitchDeg" to lastPitchDeg,
                    "rollDeg" to rawRollDeg,
                    "angularSpeed" to angularSpeedDegPerSec
                )
            )
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun normalizeAngleDeg(angle: Double): Double {
        var a = (angle + 180.0) % 360.0
        if (a < 0) a += 360.0
        return a - 180.0
    }

    override fun onDestroy() {
        stopSensors()
        super.onDestroy()
    }
}

