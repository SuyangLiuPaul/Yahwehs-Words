package com.example.yswords.wear

import android.app.Activity
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.graphics.Color
import android.view.Gravity
import android.widget.*
import com.google.android.gms.wearable.*
import org.json.JSONObject
import java.util.UUID

/** A phone companion. No watch streaming, account login, or hidden download. */
class WatchActivity : Activity(), MessageClient.OnMessageReceivedListener, DataClient.OnDataChangedListener {
    private lateinit var content: LinearLayout
    private var state = JSONObject()
    private var screen = "home"
    private val history = mutableListOf<Pair<String,String>>()
    private var folder = "car:root"
    private var title = "Listen · 聆听"
    private var items: List<JSONObject> = emptyList()
    private var error = ""
    private var activeRequest = ""
    private var connected = false
    private var loading = false
    private val callbacks = Handler(Looper.getMainLooper())
    private val pending = mutableMapOf<String, Runnable>()
    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        state = try { JSONObject(getPreferences(0).getString("state", "{}")!!) } catch (_:Exception) { JSONObject() }
        val scroll = ScrollView(this)
        content = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; gravity = Gravity.CENTER_HORIZONTAL; setPadding(dp(20),dp(20),dp(20),dp(32)) }
        scroll.addView(content); setContentView(scroll); render()
    }
    override fun onResume() {
        super.onResume()
        Wearable.getMessageClient(this).addListener(this)
        Wearable.getDataClient(this).addListener(this)
        Wearable.getDataClient(this).dataItems.addOnSuccessListener { buffer ->
            try {
                for (item in buffer) if (item.uri.path == "/words/state") {
                    val raw = DataMapItem.fromDataItem(item).dataMap.getString("json")
                    if (raw != null) try { accept(JSONObject(raw)) } catch (_: Exception) { }
                }
                render()
            } finally { buffer.release() }
        }
        send("snapshot")
    }
    override fun onPause() {
        Wearable.getMessageClient(this).removeListener(this)
        Wearable.getDataClient(this).removeListener(this)
        callbacks.removeCallbacksAndMessages(null)
        pending.clear()
        super.onPause()
    }
    override fun onMessageReceived(event: MessageEvent) {
        if (event.path != "/words/reply") return
        val reply = try { JSONObject(String(event.data, Charsets.UTF_8)) } catch (_: Exception) { return }
        runOnUiThread {
            val request = reply.optString("requestId")
            pending.remove(request)?.let { callbacks.removeCallbacks(it) }
            connected = true
            if (reply.has("items")) {
                if (reply.optString("requestId") != activeRequest) return@runOnUiThread
                loading = false
                val list = reply.getJSONArray("items")
                items = (0 until list.length()).map { list.getJSONObject(it) }
                error = ""
            } else if (reply.has("daily")) { accept(reply); error = reply.optString("error") }
            else {
                if (request == activeRequest) loading = false
                error = reply.optString("error")
            }
            render()
        }
    }
    override fun onDataChanged(events: DataEventBuffer) {
        for (event in events) if (event.type == DataEvent.TYPE_CHANGED && event.dataItem.uri.path == "/words/state") {
            val raw = DataMapItem.fromDataItem(event.dataItem).dataMap.getString("json") ?: continue
            val value = try { JSONObject(raw) } catch (_: Exception) { continue }
            runOnUiThread { accept(value); render() }
        }
    }
    private fun accept(value: JSONObject) {
        state = value
        getPreferences(0).edit().putString("state", value.toString()).apply()
    }
    private fun send(action: String, id: String? = null) {
        val request = UUID.randomUUID().toString()
        if (action == "children") activeRequest = request
        if (action == "children") loading = true
        val data = JSONObject().put("action",action).put("requestId",request)
        if (id != null) data.put("id", id)
        Wearable.getNodeClient(this).connectedNodes.addOnSuccessListener { nodes ->
            if (nodes.isEmpty()) { connected=false; loading=false; error = "Connect your phone to Words. Saved daily verse is available."; render(); return@addOnSuccessListener }
            connected = true
            // One nearby paired phone; do not trigger playback on every node.
            val node = nodes.firstOrNull { it.isNearby } ?: nodes.first()
            val timeout = Runnable {
                pending.remove(request)
                if (action == "children" && request != activeRequest) return@Runnable
                loading=false; error="Phone did not reply. Open Words and retry."; render()
            }
            pending[request] = timeout
            callbacks.postDelayed(timeout, 12000)
            Wearable.getMessageClient(this).sendMessage(node.id,"/words/command",data.toString().toByteArray())
                .addOnFailureListener { pending.remove(request)?.let { callbacks.removeCallbacks(it) };loading=false;error = "Phone unavailable. Open Words and retry."; render() }
        }.addOnFailureListener { connected=false; loading=false; error = "Could not connect to phone."; render() }
    }
    private fun text(value: String, headline: Boolean = false) {
        content.addView(TextView(this).apply { text=value; textSize=if(headline) 18f else 14f; gravity=Gravity.CENTER; setTextColor(if(headline) Color.rgb(239,167,119) else Color.WHITE); setPadding(0,dp(6),0,dp(6)) })
    }
    private fun button(label: String, enabled: Boolean = true, action: () -> Unit) {
        content.addView(Button(this).apply { text=label; textSize=13f; minHeight=dp(48); isEnabled=enabled; setOnClickListener { action() } }, LinearLayout.LayoutParams(-1,-2))
    }
    private fun render() {
        content.removeAllViews()
        when(screen) {
            "home" -> {
                text("Yahweh’s Words",true)
                button("Daily verse · 每日经文") { screen="daily";render() }
                button("Now playing · 播放") { screen="playing";render() }
                button("Hymns & sermons") { screen="library";folder="car:root";history.clear();items=emptyList();send("children",folder);render() }
            }
            "daily" -> {
                val daily=state.optJSONObject("daily") ?: JSONObject()
                text(daily.optString("reference","Daily verse"),true)
                text(daily.optString("english","Open Words on phone to sync."))
                text(daily.optString("chinese"))
                text(daily.optString("date")+" · BSB-Y / CUVS-Y")
            }
            "playing" -> {
                val sermon=state.optBoolean("sermon")
                text(state.optString("title").ifEmpty { "Choose audio from Listen" },true)
                text(state.optString("subtitle"))
                val canControl=connected && state.optString("id").isNotEmpty()
                button(if(state.optBoolean("playing")) "Pause · 暂停" else "Play · 播放",canControl) { send(if(state.optBoolean("playing")) "pause" else "play") }
                button(if(sermon) "−15 seconds" else "Previous hymn",canControl) { send(if(sermon) "backward" else "previous") }
                button(if(sermon) "+30 seconds" else "Next hymn",canControl) { send(if(sermon) "forward" else "next") }
                text("Audio plays on phone")
            }
            "library" -> {
                text(title,true)
                if(loading && error.isEmpty()) text("Loading from phone…")
                else if(items.isEmpty() && error.isEmpty()) text("No audio in this category.")
                for(item in items) button(item.optString("title")) {
                    if(item.optBoolean("playable")) { send("select",item.optString("id"));screen="playing";render() }
                    else { history.add(folder to title);folder=item.optString("id");title=item.optString("title");items=emptyList();send("children",folder);render() }
                }
            }
        }
        if(error.isNotEmpty()) text(error)
        button("Refresh · 刷新") { error=""; if(screen=="library") send("children",folder) else send("snapshot");render() }
        if(screen!="home") button("Back · 返回") { goBack() }
    }
    private fun goBack() {
        if(screen=="library" && history.isNotEmpty()) { val previous=history.removeAt(history.lastIndex);folder=previous.first;title=previous.second;items=emptyList();send("children",folder) }
        else { screen="home";error="" }
        render()
    }
    @Deprecated("Deprecated in Android") override fun onBackPressed() { goBack() }
}
