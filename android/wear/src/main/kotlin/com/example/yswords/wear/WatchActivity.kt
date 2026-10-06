package com.example.yswords.wear

import android.app.Activity
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.graphics.Color
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.drawable.GradientDrawable
import android.content.res.ColorStateList
import java.net.URL
import javax.net.ssl.HttpsURLConnection
import java.util.concurrent.Executors
import java.io.ByteArrayOutputStream
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
    private var foreground = false
    private var foregroundGeneration = 0L
    private var connectionProof = 0L
    private var loading = false
    private val callbacks = Handler(Looper.getMainLooper())
    private val pending = mutableMapOf<String, Runnable>()
    private val requestProofs = mutableMapOf<String, Long>()
    // Follow the phone's theme colour (the phone sends it as `accent`); these are
    // the original blue until a state carrying one arrives.
    private var accent = Color.rgb(84, 199, 245)
    private var surface = Color.rgb(31, 56, 77)
    private val artworkWorker = Executors.newSingleThreadExecutor()
    private var artworkUrl = ""
    private var artworkBitmap: Bitmap? = null
    private var artworkView: ImageView? = null
    private fun tr(en: String, hans: String, hant: String = hans): String = when(state.optString("locale")) { "zh-Hant" -> hant; "zh-Hans" -> hans; else -> en }
    private fun background(color: Int, radius: Int = 18) = GradientDrawable().apply { setColor(color); cornerRadius=dp(radius).toFloat() }
    private var progressText: TextView? = null
    private var progressBar: ProgressBar? = null
    private var playbackStatus: TextView? = null
    private val playbackControls = mutableListOf<Button>()
    private val modeControls = mutableListOf<Button>()
    private val progressTick = object : Runnable {
        override fun run() {
            updatePlaybackProgress()
            callbacks.postDelayed(this, 1000)
        }
    }
    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        state = try { JSONObject(getPreferences(0).getString("state", "{}")!!) } catch (_:Exception) { JSONObject() }
        applyTheme(state)
        val scroll = ScrollView(this).apply { setBackgroundColor(Color.BLACK); isVerticalScrollBarEnabled=false }
        content = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; gravity = Gravity.CENTER_HORIZONTAL; setPadding(dp(12),dp(24),dp(12),dp(32)) }
        scroll.addView(content); setContentView(scroll)
        previewLibrary()
        render()
    }
    /** Debuggable builds only: `--es preview sources|pages|sermons` shows a library list with sample rows,
     *  so the list design can be looked at on an emulator that has no phone to ask. */
    private var preview = false
    private fun previewLibrary() {
        if ((applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) == 0) return
        val kind = intent?.getStringExtra("preview") ?: return
        fun row(id: String, title: String, sub: String, art: String = "", playable: Boolean = false) =
            JSONObject().put("id", id).put("title", title).put("subtitle", sub).put("artwork", art).put("playable", playable)
        val logos = "https://yahwehword.com/assets/assets/song_sources/"
        preview = true; connected = true
        state = JSONObject().put("locale", "zh-Hans")
        screen = "library"
        when (kind) {
            "sources" -> { title = "诗歌"; items = listOf(row("car:songs/cdc", "Christian Disciples Church", "298 首", logos + "cdc.png"),
                row("car:songs/cgdc", "基督門徒福音會 CGDC", "63 首", logos + "cgdc.jpg"), row("car:songs/fydt", "福音电台 FYDT", "213 首", logos + "fydt.jpg")) }
            "pages" -> { title = "Christian Disciples Church"; items = listOf(row("car:page/vocal/cdc/0", "A – Keep", "60 首", logos + "cdc.png"),
                row("car:page/vocal/cdc/60", "Let – With", "60 首", logos + "cdc.png"), row("car:page/vocal/cdc/120", "Yahweh – 可喜可乐之城", "60 首", logos + "cdc.png")) }
            else -> { title = "讲道"; items = listOf(row("car:topic/Baptism", "Baptism", "5 篇"), row("car:topic/Death", "Death and Resurrection of Christ", "3 篇"),
                row("car:topic/Mount", "Sermon on the Mount", "39 篇"), row("car:sermon/1", "The purpose of Christ's death", "Eric H. H. Chang", playable = true)) }
        }
    }
    override fun onResume() {
        super.onResume()
        foreground = true
        val generation = ++foregroundGeneration
        connected = false
        callbacks.post(progressTick)
        Wearable.getMessageClient(this).addListener(this)
        Wearable.getDataClient(this).addListener(this)
        Wearable.getDataClient(this).dataItems.addOnSuccessListener { buffer ->
            try {
                if (!foreground || generation != foregroundGeneration) return@addOnSuccessListener
                for (item in buffer) if (item.uri.path == "/words/state") {
                    val raw = DataMapItem.fromDataItem(item).dataMap.getString("json")
                    if (raw != null) try { accept(JSONObject(raw), liveContact = false) } catch (_: Exception) { }
                }
                render()
            } finally { buffer.release() }
        }
        send("snapshot")
        if (screen == "library") send("children", folder)
    }
    override fun onPause() {
        foreground = false
        foregroundGeneration++
        Wearable.getMessageClient(this).removeListener(this)
        Wearable.getDataClient(this).removeListener(this)
        callbacks.removeCallbacksAndMessages(null)
        pending.clear()
        requestProofs.clear()
        loading = false
        activeRequest = ""
        super.onPause()
    }
    override fun onMessageReceived(event: MessageEvent) {
        if (event.path != "/words/reply") return
        val reply = try { JSONObject(String(event.data, Charsets.UTF_8)) } catch (_: Exception) { return }
        runOnUiThread {
            if (!foreground) return@runOnUiThread
            val request = reply.optString("requestId")
            // Discard replies from a previous foreground session or from
            // requests already timed out/canceled when the screen closed.
            val proofAtRequest = requestProofs.remove(request) ?: return@runOnUiThread
            pending.remove(request)?.let { callbacks.removeCallbacks(it) }
            if (reply.has("items")) {
                if (reply.optString("requestId") != activeRequest) return@runOnUiThread
                connectionProof++
                connected = true
                loading = false
                val list = reply.getJSONArray("items")
                items = (0 until list.length()).map { list.getJSONObject(it) }
                error = ""
            } else if (reply.has("daily")) { accept(reply) }
            else {
                if (request == activeRequest) {
                    // A media publication is not completion of this folder.
                    loading = false
                } else if (proofAtRequest != connectionProof) return@runOnUiThread
                error = reply.optString("error")
            }
            render()
        }
    }
    override fun onDataChanged(events: DataEventBuffer) {
        for (event in events) if (event.type == DataEvent.TYPE_CHANGED && event.dataItem.uri.path == "/words/state") {
            val raw = DataMapItem.fromDataItem(event.dataItem).dataMap.getString("json") ?: continue
            val value = try { JSONObject(raw) } catch (_: Exception) { continue }
            runOnUiThread { if (foreground) { accept(value); render() } }
        }
    }
    private fun accept(value: JSONObject, liveContact: Boolean = true) {
        if (value.optLong("syncedAt", 0) < state.optLong("syncedAt", 0)) return
        state = value
        applyTheme(value)
        if (liveContact && isFresh()) {
            connected = true
            connectionProof++
            // A fresh phone publication also recovers a failed request.
            error = value.optString("error")
        }
        getPreferences(0).edit().putString("state", value.toString()).apply()
    }
    /** The phone's theme colour, lifted for the dark screen the same way the iPhone's watch app does. */
    private fun applyTheme(value: JSONObject) {
        if (!value.has("accent")) return
        val argb = value.optLong("accent").toInt()
        var r = Color.red(argb) / 255.0
        var g = Color.green(argb) / 255.0
        var b = Color.blue(argb) / 255.0
        val luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        if (luminance < 0.45) {
            val t = minOf(0.65, (0.45 - luminance) / (1 - luminance))
            r += (1 - r) * t; g += (1 - g) * t; b += (1 - b) * t
        }
        fun channel(base: Double, weight: Double, v: Double) = ((base + weight * v).coerceIn(0.0, 1.0) * 255).toInt()
        accent = Color.rgb((r * 255).toInt(), (g * 255).toInt(), (b * 255).toInt())
        surface = Color.rgb(channel(0.06, 0.22, r), channel(0.06, 0.22, g), channel(0.06, 0.22, b))
    }
    /** The app's logo in the colour the phone uses, standing in for a cover that has not loaded. */
    private fun logoResource(): Int {
        val variant = state.optString("logo").lowercase()
        val known = setOf("red", "orange", "green", "purple", "pink", "dark")
        val id = resources.getIdentifier("logo_" + (if (variant in known) variant else "default"), "drawable", packageName)
        return if (id != 0) id else android.R.drawable.ic_media_play
    }
    private fun send(action: String, id: String? = null) {
        if (!foreground || preview) return
        val generation = foregroundGeneration
        if (action in setOf("shuffle", "repeat") && (!connected || !isFresh() || state.optBoolean("loading") || error.isNotEmpty())) return

        val request = UUID.randomUUID().toString()
        val proofAtRequest = connectionProof
        requestProofs[request] = proofAtRequest
        fun fail(message: String) {
            if (!foreground || generation != foregroundGeneration) return
            requestProofs.remove(request)
            if (action == "children" && request != activeRequest) return
            if (action == "children") loading = false
            // An older timeout cannot undo a newer successful contact.
            if (connectionProof == proofAtRequest) {
                connected = false
                error = message
            }
            render()
        }
        if (action == "children") activeRequest = request
        if (action == "children") loading = true
        val data = JSONObject().put("action",action).put("requestId",request)
        if (id != null) data.put("id", id)
        Wearable.getNodeClient(this).connectedNodes.addOnSuccessListener { nodes ->
            if (!foreground || generation != foregroundGeneration) return@addOnSuccessListener
            if (nodes.isEmpty()) { fail("Connect your phone to Words. Saved daily verse is available."); return@addOnSuccessListener }
            // One nearby paired phone; do not trigger playback on every node.
            val node = nodes.firstOrNull { it.isNearby } ?: nodes.first()
            val timeout = Runnable {
                pending.remove(request)
                fail("Phone did not reply. Open Words and retry.")
            }
            pending[request] = timeout
            callbacks.postDelayed(timeout, 12000)
            Wearable.getMessageClient(this).sendMessage(node.id,"/words/command",data.toString().toByteArray())
                .addOnFailureListener { pending.remove(request)?.let { callbacks.removeCallbacks(it) }; fail("Phone unavailable. Open Words and retry.") }
        }.addOnFailureListener { fail("Could not connect to phone.") }
    }
    private fun text(value: String, headline: Boolean = false): TextView {
        val view = TextView(this).apply { text=value; textSize=if(headline) 18f else 14f; gravity=Gravity.CENTER; setTextColor(if(headline) accent else Color.WHITE); setPadding(0,dp(6),0,dp(6)) }
        content.addView(view)
        return view
    }
    private fun button(label: String, enabled: Boolean = true, action: () -> Unit): Button {
        val view = Button(this).apply { text=label; textSize=13f; minHeight=dp(48); isAllCaps=false; setTextColor(Color.WHITE); background=background(surface); setPadding(dp(8),dp(6),dp(8),dp(6)); isEnabled=enabled; setOnClickListener { action() } }
        content.addView(view, LinearLayout.LayoutParams(-1,-2).apply { bottomMargin=dp(8) })
        return view
    }
    // ---- library rows: a tile (the item's own artwork, or a themed glyph tile) + title + subtitle ----
    private val rowArtwork = object : android.util.LruCache<String, Bitmap>(48) {}
    private fun tileGlyph(item: JSONObject): String {
        val id = item.optString("id"); val title = item.optString("title")
        return when {
            id == "car:queue" || id.startsWith("car:queue-page") -> "≡"
            id == "car:playlists" || id.startsWith("car:playlist/") -> "♫"
            id.contains("instrumental") -> "♬"
            item.optBoolean("playable") -> "♪"
            else -> title.firstOrNull { it.isLetterOrDigit() }?.uppercaseChar()?.toString() ?: "♪"
        }
    }
    private fun themedTile(size: Int): GradientDrawable = GradientDrawable(
        GradientDrawable.Orientation.TL_BR, intArrayOf(accent, Color.argb(255, (Color.red(accent) * 0.55).toInt(), (Color.green(accent) * 0.55).toInt(), (Color.blue(accent) * 0.55).toInt()))
    ).apply { cornerRadius = dp(size / 4).toFloat() }
    private fun fetchRowArtwork(raw: String, done: (Bitmap?) -> Unit) {
        rowArtwork.get(raw)?.let { done(it); return }
        val url = try { URL(raw).takeIf { it.protocol == "https" && it.host.isNotEmpty() && it.userInfo == null } } catch (_: Exception) { null } ?: return done(null)
        artworkWorker.execute {
            var connection: HttpsURLConnection? = null
            val bitmap = try {
                connection = url.openConnection() as HttpsURLConnection
                connection!!.connectTimeout = 5000; connection!!.readTimeout = 5000; connection!!.instanceFollowRedirects = false
                if (connection!!.responseCode != 200) throw IllegalStateException()
                val bytes = connection!!.inputStream.use { input ->
                    val output = ByteArrayOutputStream(); val buffer = ByteArray(8192)
                    while (true) { val count = input.read(buffer); if (count < 0) break; if (output.size() + count > 512 * 1024) throw IllegalStateException(); output.write(buffer, 0, count) }
                    output.toByteArray()
                }
                val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }; BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
                if (bounds.outWidth !in 1..4096 || bounds.outHeight !in 1..4096) throw IllegalStateException()
                val options = BitmapFactory.Options().apply { inSampleSize = 1 }; while (maxOf(bounds.outWidth, bounds.outHeight) / options.inSampleSize > 160) options.inSampleSize *= 2
                BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
            } catch (_: Exception) { null } finally { connection?.disconnect() }
            if (bitmap != null) rowArtwork.put(raw, bitmap)
            runOnUiThread { if (!isFinishing && !isDestroyed) done(bitmap) }
        }
    }
    private fun libraryRow(item: JSONObject, action: () -> Unit) {
        val size = 36
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL
            background = background(surface); setPadding(dp(8), dp(6), dp(10), dp(6)); minimumHeight = dp(52)
            setOnClickListener { action() }
        }
        val glyph = TextView(this).apply { text = tileGlyph(item); textSize = 16f; setTextColor(Color.WHITE); gravity = Gravity.CENTER; typeface = android.graphics.Typeface.DEFAULT_BOLD }
        val tile = FrameLayout(this).apply { background = themedTile(size); clipToOutline = true; addView(glyph, FrameLayout.LayoutParams(-1, -1)) }
        val image = ImageView(this).apply { scaleType = ImageView.ScaleType.CENTER_CROP; visibility = android.view.View.GONE }
        tile.addView(image, FrameLayout.LayoutParams(-1, -1))
        val art = item.optString("artwork")
        // The themed logo is the stand-in for "no cover"; only real covers and source logos are worth fetching.
        if (art.isNotEmpty() && !art.contains("/icons/Icon-")) {
            fun show(b: Bitmap) { image.setImageBitmap(b); image.visibility = android.view.View.VISIBLE; glyph.visibility = android.view.View.GONE }
            fetchRowArtwork(art) { b -> if (b != null) show(b) }
        }
        row.addView(tile, LinearLayout.LayoutParams(dp(size), dp(size)).apply { marginEnd = dp(8) })
        val texts = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        texts.addView(TextView(this).apply { text = item.optString("title"); textSize = 13f; setTextColor(Color.WHITE); maxLines = 2; ellipsize = android.text.TextUtils.TruncateAt.END; typeface = android.graphics.Typeface.DEFAULT_BOLD })
        val sub = item.optString("subtitle")
        if (sub.isNotEmpty()) texts.addView(TextView(this).apply { text = sub; textSize = 11f; setTextColor(Color.rgb(202, 220, 235)); maxLines = 1; ellipsize = android.text.TextUtils.TruncateAt.END })
        row.addView(texts, LinearLayout.LayoutParams(0, -2, 1f))
        if (!item.optBoolean("playable")) row.addView(TextView(this).apply { text = "›"; textSize = 18f; setTextColor(Color.rgb(202, 220, 235)) })
        content.addView(row, LinearLayout.LayoutParams(-1, -2).apply { bottomMargin = dp(8) })
    }
    private fun artwork(size: Int = 68) {
        val image = ImageView(this).apply { scaleType=ImageView.ScaleType.FIT_CENTER; background=background(Color.rgb(232, 245, 255),14); setPadding(dp(3),dp(3),dp(3),dp(3)); contentDescription=null }
        artworkView=image
        content.addView(image,LinearLayout.LayoutParams(dp(size),dp(size)).apply { bottomMargin=dp(8) })
        val raw=state.optString("artwork")
        if(raw==artworkUrl && artworkBitmap!=null) { image.setImageBitmap(artworkBitmap); return }
        image.setImageResource(logoResource())
        image.imageTintList=null
        if(raw.isEmpty() || raw==artworkUrl) return
        val url=try { URL(raw).takeIf { it.protocol=="https" && it.host.isNotEmpty() && it.userInfo==null } } catch(_:Exception){null} ?: return
        artworkUrl=raw;artworkBitmap=null
        artworkWorker.execute {
            var connection: HttpsURLConnection?=null
            val bitmap=try {
                connection=url.openConnection() as HttpsURLConnection
                connection!!.connectTimeout=5000;connection!!.readTimeout=5000;connection!!.instanceFollowRedirects=false
                if(connection!!.responseCode!=200) throw IllegalStateException()
                val bytes=connection!!.inputStream.use { input ->
                    val output=ByteArrayOutputStream();val buffer=ByteArray(8192)
                    while(true) { val count=input.read(buffer);if(count<0)break;if(output.size()+count>512*1024)throw IllegalStateException();output.write(buffer,0,count) }
                    output.toByteArray()
                }
                val bounds=BitmapFactory.Options().apply { inJustDecodeBounds=true };BitmapFactory.decodeByteArray(bytes,0,bytes.size,bounds)
                if(bounds.outWidth !in 1..4096 || bounds.outHeight !in 1..4096) throw IllegalStateException()
                val options=BitmapFactory.Options().apply { inSampleSize=1 };while(maxOf(bounds.outWidth,bounds.outHeight)/options.inSampleSize>256) options.inSampleSize*=2
                BitmapFactory.decodeByteArray(bytes,0,bytes.size,options)
            }catch(_:Exception){null}finally{connection?.disconnect()}
            runOnUiThread {
                if (!isFinishing && !isDestroyed && artworkUrl == raw) {
                    if (bitmap != null) {
                        artworkBitmap=bitmap;artworkView?.imageTintList=null;artworkView?.setImageBitmap(bitmap)
                    } else { artworkUrl="" } // Retry a failed cover on the next fresh publication.
                }
            }
        }
    }
    private fun transportRow(sermon: Boolean) {
        val row=LinearLayout(this).apply { orientation=LinearLayout.HORIZONTAL;gravity=Gravity.CENTER }
        fun control(symbol:String,label:String,primary:Boolean,action:()->Unit):Button = Button(this).apply {
            text=symbol;contentDescription=label;textSize=if(primary)22f else 18f;isAllCaps=false;minWidth=0;minimumWidth=0;minHeight=0;minimumHeight=0;setPadding(0,0,0,0)
            setTextColor(if(primary)Color.BLACK else Color.WHITE);background=background(if(primary)accent else surface,30);isEnabled=false;setOnClickListener{action()}
        }
        val back=control(if(sermon)"↶15" else "⏮",if(sermon)tr("Back 15 seconds","快退 15 秒") else tr("Previous hymn","上一首"),false){send(if(sermon)"backward" else "previous")}
        val play=control(if(state.optBoolean("playing"))"Ⅱ" else "▶",if(state.optBoolean("playing"))tr("Pause","暂停","暫停") else tr("Play","播放"),true){send(if(state.optBoolean("playing"))"pause" else "play")}
        val next=control(if(sermon)"30↷" else "⏭",if(sermon)tr("Forward 30 seconds","快进 30 秒","快進 30 秒") else tr("Next hymn","下一首"),false){send(if(sermon)"forward" else "next")}
        for((view,size) in listOf(back to 44,play to 52,next to 44)) row.addView(view,LinearLayout.LayoutParams(0,dp(size),if(view===play)1.18f else 1f).apply { leftMargin=dp(2);rightMargin=dp(2);gravity=Gravity.CENTER_VERTICAL })
        playbackControls.addAll(listOf(play,back,next));content.addView(row,LinearLayout.LayoutParams(-1,-2).apply { topMargin=dp(8);bottomMargin=dp(8) })
    }
    override fun onDestroy() { artworkWorker.shutdownNow();artworkView=null;artworkBitmap=null;super.onDestroy() }
    private fun isFresh(): Boolean {
        val syncedAt = state.optLong("syncedAt", 0)
        return syncedAt > 0 && System.currentTimeMillis() - syncedAt in -5000L..45000L
    }
    private fun clock(seconds: Long): String {
        val value = seconds.coerceAtLeast(0)
        return if (value >= 3600) "%d:%02d:%02d".format(value / 3600, value / 60 % 60, value % 60)
        else "%d:%02d".format(value / 60, value % 60)
    }
    private fun updatePlaybackProgress() {
        if (screen != "playing") return
        val live = connected && isFresh()
        val busy = state.optBoolean("loading")
        val canControl = live && !busy && error.isEmpty() && state.optString("error").isEmpty() && state.optString("id").isNotEmpty()
        modeControls.forEach { it.isEnabled = canControl; it.alpha = if(canControl) 1f else 0.45f }
        playbackControls.forEachIndexed { index, button ->
            button.isEnabled = canControl && (index == 0 || state.optBoolean("sermon") || state.optBoolean(if (index == 1) "canPrevious" else "canNext", state.optBoolean("canSkip")))
        }
        val total = state.optLong("duration", 0).coerceAtLeast(0)
        val advance = if (live && state.optBoolean("playing") && !busy && state.optString("error").isEmpty())
            (System.currentTimeMillis() - state.optLong("syncedAt")).coerceAtLeast(0) / 1000 else 0
        val elapsed = (state.optLong("position", 0).coerceAtLeast(0) + advance)
            .let { if (total > 0) it.coerceAtMost(total) else it }
        progressText?.text = "${clock(elapsed)} / ${if (total > 0) clock(total) else "—"}"
        progressBar?.apply {
            visibility = if (total > 0) android.view.View.VISIBLE else android.view.View.GONE
            progress = if (total > 0) (elapsed * 1000 / total).toInt() else 0
            contentDescription = progressText?.text
        }
        playbackStatus?.text = when {
            !live -> tr("Saved playback · reconnect phone","已保存 · 重新连接手机","已儲存 · 重新連接手機")
            state.optString("error").isNotEmpty() -> state.optString("error")
            busy -> tr("Loading on phone…","手机正在加载…","手機正在載入…")
            state.optBoolean("playing") -> tr("Audio plays on phone","音频在手机播放","音訊在手機播放")
            else -> tr("Paused on phone","手机已暂停","手機已暫停")
        }
    }
    private fun render() {
        content.removeAllViews()
        artworkView=null
        progressText = null
        progressBar = null
        playbackStatus = null
        playbackControls.clear()
        modeControls.clear()
        when(screen) {
            "home" -> {
                text("Yahweh’s Words",true)
                if(state.optString("id").isNotEmpty()) { artwork();text(state.optString("title"),true) }
                button(tr("Bible · phone chapter","圣经 · 手机当前章节","聖經 · 手機目前章節")) { screen="bible";render() }
                button(tr("Daily verse","每日经文","每日經文")) { screen="daily";render() }
                button(tr("Now playing","正在播放")) { screen="playing";render() }
                button(tr("Hymns & sermons","诗歌与讲道","詩歌與講道")) { screen="library";folder="car:root";history.clear();items=emptyList();send("children",folder);render() }
            }
            "daily" -> {
                val daily=state.optJSONObject("daily") ?: JSONObject()
                text(daily.optString("reference","Daily verse"),true)
                text(daily.optString("english","Open Words on phone to sync."))
                text(daily.optString("chinese"))
                text(daily.optString("date")+" · BSB-Y / CUVS-Y")
            }
            "bible" -> {
                val reading=state.optJSONObject("reading") ?: JSONObject()
                text(reading.optString("reference",tr("Bible","圣经","聖經")),true)
                text(reading.optString("versionLabel",reading.optString("version")))
                text(if(connected && isFresh())tr("Follows your phone chapter","跟随手机所选章节","跟隨手機所選章節") else tr("Saved chapter · reconnect to update","已保存章节 · 连接后更新","已儲存章節 · 連接後更新"))
                val verses=reading.optJSONArray("verses")
                if(verses==null || verses.length()==0) text(tr("Open a Bible chapter in Words on phone, then refresh.","在手机 Words 打开圣经章节，然后刷新。","在手機 Words 開啟聖經章節，然後重新整理。"))
                if(verses!=null) for(index in 0 until verses.length()) {
                    val verse=verses.getJSONObject(index)
                    if(verse.optString("heading").isNotEmpty())text(verse.optString("heading"))
                    text(verse.optString("number")+"  "+verse.optString("text")).gravity=Gravity.START
                }
                if(reading.optBoolean("truncated")) text(tr("Transfer limit reached. Read the remaining verses on phone.","已达到传输上限；其余经文请在手机阅读。","已達到傳輸上限；其餘經文請在手機閱讀。"))
            }
            "playing" -> {
                val sermon=state.optBoolean("sermon")
                artwork(64)
                text(state.optString("title").ifEmpty { tr("Choose audio from Listen","从聆听选择音频","從聆聽選擇音訊") },true)
                text(state.optString("subtitle"))
                progressText = text("")
                progressBar = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply { max = 1000;progressTintList=ColorStateList.valueOf(accent);progressBackgroundTintList=ColorStateList.valueOf(surface) }
                content.addView(progressBar, LinearLayout.LayoutParams(-1, dp(6)))
                transportRow(sermon)
                if (!sermon && state.optInt("queueCount") > 0) {
                    text("${state.optInt("queueIndex") + 1} / ${state.optInt("queueCount")} · ${state.optString("queueLabel")}")
                    modeControls.add(button(tr("Shuffle", "随机播放", "隨機播放") + if(state.optBoolean("shuffled")) " ✓" else " —") {
                        send("shuffle", if(state.optBoolean("shuffled")) "off" else "on")
                    })
                    val repeat = state.optString("repeat", "off")
                    modeControls.add(button(when(repeat) { "one" -> tr("Repeat one", "单曲循环", "單曲循環"); "all" -> tr("Repeat queue", "列表循环", "清單循環"); else -> tr("Repeat off", "不循环", "不循環") }) {
                        send("repeat", when(repeat) { "off" -> "all"; "all" -> "one"; else -> "off" })
                    })
                    button(tr("Playing queue", "播放队列", "播放佇列")) {
                        screen="library"; folder="car:queue"; title=tr("Playing queue", "播放队列", "播放佇列"); history.clear(); items=emptyList(); send("children",folder); render()
                    }
                }
                playbackStatus = text("")
                updatePlaybackProgress()
            }
            "library" -> {
                text(title,true)
                if(loading && error.isEmpty()) text(tr("Loading from phone…","正在从手机加载…","正在從手機載入…"))
                else if(items.isEmpty() && error.isEmpty()) text(tr("No audio in this category.","此分类暂无音频。","此分類暫無音訊。"))
                for(item in items) libraryRow(item) {
                    if(item.optBoolean("playable")) { send("select",item.optString("id"));screen="playing";render() }
                    else { history.add(folder to title);folder=item.optString("id");title=item.optString("title");items=emptyList();send("children",folder);render() }
                }
            }
        }
        if(error.isNotEmpty()) text(error)
        button(tr("Refresh","刷新","重新整理")) { error="";if(artworkBitmap==null)artworkUrl=""; if(screen=="library") send("children",folder) else send("snapshot");render() }
        if(screen!="home") button(tr("Back","返回")) { goBack() }
    }
    private fun goBack() {
        if(screen=="library" && history.isNotEmpty()) { val previous=history.removeAt(history.lastIndex);folder=previous.first;title=previous.second;items=emptyList();send("children",folder) }
        else { screen="home";error="" }
        render()
    }
    @Deprecated("Deprecated in Android") override fun onBackPressed() { goBack() }
}
