package com.example.yswords

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.google.android.gms.wearable.*
import com.ryanheise.audioservice.AudioServicePlugin
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

object WordsWearBridge {
    private var channel: MethodChannel? = null
    private var identity = ""
    private var sentAt = 0L
    private var sentPosition = 0.0
    private var sentPlaying = false
    fun install(context: Context, engine: FlutterEngine) {
        if (channel != null) return
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, "yswords/media_companion")
        channel!!.setMethodCallHandler { call, result ->
            if (call.method != "state") { result.notImplemented(); return@setMethodCallHandler }
            val data = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
            val metadata = linkedMapOf<String, Any?>()
            for (key in listOf("id", "title", "subtitle", "artwork", "locale", "reading", "duration", "loading", "canSkip", "canNext", "canPrevious", "playing", "error", "sermon", "queueIndex", "queueCount", "queueLabel", "shuffled", "repeat")) metadata[key] = data[key]
            val next = JSONObject(metadata).toString()
            val now = System.currentTimeMillis()
            val position = (data["position"] as? Number)?.toDouble() ?: 0.0
            val expected = sentPosition + if (sentPlaying) (now - sentAt).coerceAtLeast(0) / 1000.0 else 0.0
            val discontinuity = kotlin.math.abs(position - expected) > 2
            if (identity != next || discontinuity || now - sentAt >= 15000) {
                val request = PutDataMapRequest.create("/words/state")
                request.dataMap.putString("json", JSONObject(data).toString())
                identity = next; sentAt = now; sentPosition = position; sentPlaying = data["playing"] == true && data["loading"] != true
                Wearable.getDataClient(context).putDataItem(request.asPutDataRequest().setUrgent())
                    .addOnFailureListener {
                        // Retry the current state on the next Flutter tick.
                        if (identity == next && sentAt == now) { identity = ""; sentAt = 0 }
                    }
            }
            result.success(null)
        }
    }
    fun request(context: Context, event: MessageEvent) {
        Handler(Looper.getMainLooper()).post {
            val engine = AudioServicePlugin.getFlutterEngine(context)
            install(context.applicationContext, engine)
            val data = try { JSONObject(String(event.data, Charsets.UTF_8)) } catch (_: Exception) { return@post }
            val action = data.optString("action", "snapshot")
            val allowed = setOf("play", "pause", "next", "previous", "forward", "backward", "stop", "select", "shuffle", "repeat")
            val method = when { action == "snapshot" -> "snapshot"; action == "children" -> "children"; action in allowed -> "command"; else -> return@post }
            val args = mutableMapOf<String, Any>("action" to action)
            if (data.has("id")) args["id"] = data.getString("id")
            channel!!.invokeMethod(method, if (method == "snapshot") null else args, object : MethodChannel.Result {
                override fun success(result: Any?) {
                    val reply = if (method == "children") JSONObject().put("items", org.json.JSONArray(result as? List<*> ?: emptyList<Any>()))
                        else JSONObject(result as? Map<*, *> ?: emptyMap<String, Any>())
                    reply.put("requestId", data.optString("requestId"))
                    Wearable.getMessageClient(context).sendMessage(event.sourceNodeId, "/words/reply", reply.toString().toByteArray())
                }
                override fun error(code: String, message: String?, details: Any?) { replyError(message ?: code) }
                override fun notImplemented() { replyError("Open Words on your phone to connect.") }
                private fun replyError(message: String) {
                    val reply = JSONObject().put("error", message).put("requestId", data.optString("requestId"))
                    Wearable.getMessageClient(context).sendMessage(event.sourceNodeId, "/words/reply", reply.toString().toByteArray())
                }
            })
        }
    }
}

class WordsWearListener : WearableListenerService() {
    override fun onMessageReceived(event: MessageEvent) {
        if (event.path == "/words/command") WordsWearBridge.request(applicationContext, event)
    }
}
