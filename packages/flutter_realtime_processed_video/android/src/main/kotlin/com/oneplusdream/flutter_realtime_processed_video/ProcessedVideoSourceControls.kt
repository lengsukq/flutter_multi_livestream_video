package com.oneplusdream.flutter_realtime_processed_video
import java.util.concurrent.ConcurrentHashMap

object ProcessedVideoSourceControls {
    private data class Control(val enable: (Boolean) -> Unit, val camera: (String?) -> Unit)
    private val controls = ConcurrentHashMap<String, Control>()
    fun register(id: String, enable: (Boolean) -> Unit, camera: (String?) -> Unit) { controls[id] = Control(enable, camera) }
    fun unregister(id: String) { controls.remove(id) }
    fun setEnabled(id: String, enabled: Boolean) { requireNotNull(controls[id]) { "Unknown processed source" }.enable(enabled) }
    fun selectCamera(id: String, camera: String?) { requireNotNull(controls[id]) { "Unknown processed source" }.camera(camera) }
}
