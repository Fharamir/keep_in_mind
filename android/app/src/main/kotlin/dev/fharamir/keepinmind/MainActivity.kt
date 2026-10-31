package dev.fharamir.keepinmind

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import android.widget.MediaController
import android.widget.Toast
import android.widget.VideoView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val shareChannelName = "dev.fharamir.keepinmind/share"
    private val shareStreamName = "dev.fharamir.keepinmind/share_stream"
    private val widgetChannelName = "dev.fharamir.keepinmind/widget"
    private val mediaChannelName = "dev.fharamir.keepinmind/media"

    private var initialPayload: Map<String, Any?>? = null
    private var eventSink: EventChannel.EventSink? = null

    private val reqCameraPerm = 2001
    private val reqAudioPerm = 2002
    private val reqImageCapture = 2003

    private var pendingMediaResult: MethodChannel.Result? = null
    private var currentPhotoFile: File? = null
    private var mediaRecorder: MediaRecorder? = null
    private var currentAudioFile: File? = null
    private var mediaPlayer: MediaPlayer? = null
    private var currentPlayingPath: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Handle incoming share intents silently without launching the Flutter UI
        if (isShareIntent(intent)) {
            super.onCreate(savedInstanceState)
            handleShareIntentDirectly(intent)
            finish()
            return
        }

        super.onCreate(savedInstanceState)
        initialPayload = extractPayloadFromIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        
        if (isShareIntent(intent)) {
            handleShareIntentDirectly(intent)
            finish()
            return
        }

        val payload = extractPayloadFromIntent(intent)
        if (payload != null) {
            eventSink?.success(payload)
        }
    }

    private fun isShareIntent(intent: Intent?): Boolean {
        if (intent == null) return false
        val action = intent.action
        return action == Intent.ACTION_SEND || action == Intent.ACTION_SEND_MULTIPLE
    }

    private fun handleShareIntentDirectly(intent: Intent) {
        val payload = extractPayloadFromIntent(intent) ?: return
        try {
            savePayloadDirectly(payload)
            Toast.makeText(applicationContext, "Salvato in Keep in Mind", Toast.LENGTH_SHORT).show()
        } catch (e: Exception) {
            Toast.makeText(applicationContext, "Errore durante il salvataggio", Toast.LENGTH_SHORT).show()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, shareChannelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "getInitialSharedPayload") {
                    val payload = initialPayload
                    initialPayload = null
                    result.success(payload)
                } else {
                    result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, shareStreamName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, widgetChannelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "updateWidget") {
                    val json = call.argument<String>("payloadJson")
                    val prefs = getSharedPreferences(
                        KeepInMindWidgetProvider.PREFS_NAME,
                        Context.MODE_PRIVATE
                    )
                    prefs.edit().putString(KeepInMindWidgetProvider.KEY_PAYLOAD, json).apply()
                    KeepInMindWidgetProvider.updateAllWidgets(applicationContext)
                    result.success(true)
                } else {
                    result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, mediaChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "capturePhoto" -> handleCapturePhoto(result)
                    "startAudioRecording" -> handleStartAudioRecording(result)
                    "stopAudioRecording" -> handleStopAudioRecording(result)
                    "closeToHomeScreen" -> {
                        moveTaskToBack(true)
                        result.success(true)
                    }
                    "audioPlay" -> {
                        val path = call.argument<String>("filePath")
                        handleAudioPlay(path, result)
                    }
                    "audioPause" -> {
                        try {
                            if (mediaPlayer?.isPlaying == true) {
                                mediaPlayer?.pause()
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("AUDIO_PAUSE_ERR", e.message, null)
                        }
                    }
                    "audioStop" -> {
                        stopAndReleasePlayer()
                        result.success(true)
                    }
                    "audioSeek" -> {
                        val positionMs = call.argument<Int>("positionMs") ?: 0
                        try {
                            mediaPlayer?.seekTo(positionMs)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("AUDIO_SEEK_ERR", e.message, null)
                        }
                    }
                    "audioGetStatus" -> {
                        try {
                            val mp = mediaPlayer
                            if (mp != null) {
                                result.success(
                                    mapOf(
                                        "isPlaying" to mp.isPlaying,
                                        "positionMs" to mp.currentPosition,
                                        "durationMs" to mp.duration.coerceAtLeast(0)
                                    )
                                )
                            } else {
                                result.success(
                                    mapOf(
                                        "isPlaying" to false,
                                        "positionMs" to 0,
                                        "durationMs" to 0
                                    )
                                )
                            }
                        } catch (_: Exception) {
                            result.success(
                                mapOf(
                                    "isPlaying" to false,
                                    "positionMs" to 0,
                                    "durationMs" to 0
                                )
                            )
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(
                "keep_in_mind_video_view",
                LocalVideoViewFactory()
            )
    }

    private fun handleAudioPlay(filePath: String?, result: MethodChannel.Result) {
        if (filePath.isNullOrEmpty()) {
            result.error("INVALID_PATH", "Percorso audio vuoto", null)
            return
        }
        try {
            if (mediaPlayer != null && currentPlayingPath == filePath) {
                mediaPlayer?.start()
                result.success(
                    mapOf(
                        "isPlaying" to true,
                        "positionMs" to (mediaPlayer?.currentPosition ?: 0),
                        "durationMs" to (mediaPlayer?.duration ?: 0)
                    )
                )
                return
            }
            stopAndReleasePlayer()
            val mp = MediaPlayer()
            mp.setDataSource(filePath)
            mp.prepare()
            mp.start()
            mp.setOnCompletionListener {
                it.seekTo(0)
            }
            mediaPlayer = mp
            currentPlayingPath = filePath
            result.success(
                mapOf(
                    "isPlaying" to true,
                    "positionMs" to mp.currentPosition,
                    "durationMs" to mp.duration.coerceAtLeast(0)
                )
            )
        } catch (e: Exception) {
            stopAndReleasePlayer()
            result.error("AUDIO_PLAY_ERR", e.message, null)
        }
    }

    private fun stopAndReleasePlayer() {
        try {
            mediaPlayer?.stop()
        } catch (_: Exception) {
        }
        try {
            mediaPlayer?.release()
        } catch (_: Exception) {
        }
        mediaPlayer = null
        currentPlayingPath = null
    }

    private fun handleCapturePhoto(result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
            != PackageManager.PERMISSION_GRANTED
        ) {
            pendingMediaResult = result
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.CAMERA),
                reqCameraPerm
            )
            return
        }
        launchCameraIntent(result)
    }

    private fun launchCameraIntent(result: MethodChannel.Result) {
        try {
            pendingMediaResult = result
            val attachmentsDir = File(filesDir, "keep_in_mind_attachments")
            if (!attachmentsDir.exists()) attachmentsDir.mkdirs()
            val fileName = "foto_${System.currentTimeMillis()}.jpg"
            val photoFile = File(attachmentsDir, fileName)
            currentPhotoFile = photoFile
            val photoUri = FileProvider.getUriForFile(this, "${packageName}.fileprovider", photoFile)

            val takePictureIntent = Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
                putExtra(MediaStore.EXTRA_OUTPUT, photoUri)
                addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivityForResult(takePictureIntent, reqImageCapture)
        } catch (e: Exception) {
            pendingMediaResult = null
            result.error("CAMERA_ERROR", e.message, null)
        }
    }

    private fun handleStartAudioRecording(result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED
        ) {
            pendingMediaResult = result
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.RECORD_AUDIO),
                reqAudioPerm
            )
            return
        }
        startRecorderNow(result)
    }

    private fun startRecorderNow(result: MethodChannel.Result) {
        try {
            stopAndReleaseRecorder()
            val attachmentsDir = File(filesDir, "keep_in_mind_attachments")
            if (!attachmentsDir.exists()) {
                attachmentsDir.mkdirs()
            }
            val outFile = File(attachmentsDir, "audio_${System.currentTimeMillis()}.m4a")
            val recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(this)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }
            recorder.setAudioSource(MediaRecorder.AudioSource.MIC)
            recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            recorder.setAudioSamplingRate(44100)
            recorder.setAudioEncodingBitRate(96000)
            recorder.setOutputFile(outFile.absolutePath)
            recorder.prepare()
            recorder.start()

            mediaRecorder = recorder
            currentAudioFile = outFile
            result.success(true)
        } catch (e: Exception) {
            stopAndReleaseRecorder()
            result.error("AUDIO_ERROR", e.message, null)
        }
    }

    private fun handleStopAudioRecording(result: MethodChannel.Result) {
        val outFile = currentAudioFile
        try {
            mediaRecorder?.stop()
        } catch (_: Exception) {
        } finally {
            stopAndReleaseRecorder()
        }

        if (outFile != null && outFile.exists()) {
            result.success(
                mapOf(
                    "filePath" to outFile.absolutePath,
                    "fileName" to outFile.name,
                    "mimeType" to "audio/mp4",
                    "fileSizeBytes" to outFile.length()
                )
            )
        } else {
            result.error("NO_AUDIO_FILE", "Nessun file audio registrato", null)
        }
    }

    private fun stopAndReleaseRecorder() {
        try {
            mediaRecorder?.release()
        } catch (_: Exception) {
        }
        mediaRecorder = null
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        if (requestCode == reqCameraPerm) {
            val res = pendingMediaResult ?: return
            pendingMediaResult = null
            if (granted) {
                launchCameraIntent(res)
            } else {
                res.error("PERMISSION_DENIED", "Permesso fotocamera negato", null)
            }
        } else if (requestCode == reqAudioPerm) {
            val res = pendingMediaResult ?: return
            pendingMediaResult = null
            if (granted) {
                startRecorderNow(res)
            } else {
                res.error("PERMISSION_DENIED", "Permesso microfono negato", null)
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == reqImageCapture) {
            val res = pendingMediaResult ?: return
            pendingMediaResult = null
            if (resultCode == Activity.RESULT_OK) {
                val photoFile = currentPhotoFile
                if (photoFile != null && photoFile.exists() && photoFile.length() > 0) {
                    res.success(
                        mapOf(
                            "filePath" to photoFile.absolutePath,
                            "fileName" to photoFile.name,
                            "mimeType" to "image/jpeg",
                            "fileSizeBytes" to photoFile.length()
                        )
                    )
                    currentPhotoFile = null
                    return
                }

                // Fallback: thumbnail from Intent data if camera didn't write to EXTRA_OUTPUT
                val bitmap = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    data?.extras?.getParcelable("data", Bitmap::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    data?.extras?.getParcelable("data") as? Bitmap
                }
                if (bitmap != null) {
                    try {
                        val attachmentsDir = File(filesDir, "keep_in_mind_attachments")
                        if (!attachmentsDir.exists()) attachmentsDir.mkdirs()
                        val fileName = "foto_${System.currentTimeMillis()}.jpg"
                        val destFile = File(attachmentsDir, fileName)
                        FileOutputStream(destFile).use { out ->
                            bitmap.compress(Bitmap.CompressFormat.JPEG, 92, out)
                        }
                        res.success(
                            mapOf(
                                "filePath" to destFile.absolutePath,
                                "fileName" to fileName,
                                "mimeType" to "image/jpeg",
                                "fileSizeBytes" to destFile.length()
                            )
                        )
                    } catch (e: Exception) {
                        res.error("SAVE_ERROR", e.message, null)
                    }
                } else {
                    res.success(null)
                }
            } else {
                currentPhotoFile?.delete()
                currentPhotoFile = null
                res.success(null)
            }
        }
    }

    private fun extractPayloadFromIntent(intent: Intent?): Map<String, Any?>? {
        if (intent == null) return null
        val action = intent.action ?: return null

        if (action == KeepInMindWidgetProvider.ACTION_QUICK_ADD) {
            return mapOf("quickAdd" to true, "source" to "Widget Home")
        }

        if (action == KeepInMindWidgetProvider.ACTION_OPEN_ITEM) {
            val itemId = intent.getStringExtra(KeepInMindWidgetProvider.EXTRA_ITEM_ID)
            if (!itemId.isNullOrEmpty()) {
                return mapOf("openItemId" to itemId, "source" to "Widget Home")
            }
        }

        if (action == Intent.ACTION_SEND) {
            val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
            val sharedSubject = intent.getStringExtra(Intent.EXTRA_SUBJECT)
            val mimeType = intent.type
            val streamUri = getParcelableExtraCompat(intent, Intent.EXTRA_STREAM)

            if (streamUri != null) {
                val fileMeta = copyUriToLocalStorage(streamUri, mimeType)
                return mapOf(
                    "text" to sharedText,
                    "subject" to sharedSubject,
                    "filePath" to fileMeta["filePath"],
                    "fileName" to fileMeta["fileName"],
                    "mimeType" to (fileMeta["mimeType"] ?: mimeType),
                    "fileSizeBytes" to fileMeta["fileSizeBytes"],
                    "source" to "Share to Self"
                )
            }

            if (!sharedText.isNullOrBlank() || !sharedSubject.isNullOrBlank()) {
                return mapOf(
                    "text" to (sharedText ?: sharedSubject),
                    "subject" to sharedSubject,
                    "mimeType" to mimeType,
                    "source" to "Share to Self"
                )
            }
        }

        if (action == Intent.ACTION_SEND_MULTIPLE) {
            val uris = getParcelableArrayListExtraCompat(intent, Intent.EXTRA_STREAM)
            val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
            val sharedSubject = intent.getStringExtra(Intent.EXTRA_SUBJECT)
            val mimeType = intent.type
            if (!uris.isNullOrEmpty()) {
                val items = uris.map { uri ->
                    val fileMeta = copyUriToLocalStorage(uri, mimeType)
                    mapOf(
                        "text" to sharedText,
                        "subject" to sharedSubject,
                        "filePath" to fileMeta["filePath"],
                        "fileName" to fileMeta["fileName"],
                        "mimeType" to (fileMeta["mimeType"] ?: mimeType),
                        "fileSizeBytes" to fileMeta["fileSizeBytes"],
                        "source" to "Share to Self"
                    )
                }
                return mapOf("items" to items)
            }
        }

        return null
    }

    private fun getParcelableExtraCompat(intent: Intent, key: String): Uri? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(key, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(key)
        }
    }

    private fun getParcelableArrayListExtraCompat(intent: Intent, key: String): ArrayList<Uri>? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableArrayListExtra(key, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableArrayListExtra(key)
        }
    }

    private fun copyUriToLocalStorage(uri: Uri, fallbackMime: String?): Map<String, Any?> {
        var displayName = "allegato_${System.currentTimeMillis()}"
        var sizeBytes: Long? = null
        val resolvedMime = contentResolver.getType(uri) ?: fallbackMime

        try {
            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                if (cursor.moveToFirst()) {
                    if (nameIndex != -1) {
                        displayName = cursor.getString(nameIndex) ?: displayName
                    }
                    if (sizeIndex != -1 && !cursor.isNull(sizeIndex)) {
                        sizeBytes = cursor.getLong(sizeIndex)
                    }
                }
            }

            val sanitized = displayName.replace(Regex("[^a-zA-Z0-9._-]"), "_")
            val attachmentsDir = File(filesDir, "keep_in_mind_attachments")
            if (!attachmentsDir.exists()) {
                attachmentsDir.mkdirs()
            }
            val destFile = File(attachmentsDir, "${System.currentTimeMillis()}_$sanitized")

            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(destFile).use { output ->
                    input.copyTo(output)
                }
            }

            val finalSize = sizeBytes ?: destFile.length()
            return mapOf(
                "filePath" to destFile.absolutePath,
                "fileName" to displayName,
                "mimeType" to resolvedMime,
                "fileSizeBytes" to finalSize
            )
        } catch (_: Exception) {
            return mapOf(
                "filePath" to uri.toString(),
                "fileName" to displayName,
                "mimeType" to resolvedMime,
                "fileSizeBytes" to sizeBytes
            )
        }
    }

    private fun savePayloadDirectly(payload: Map<String, Any?>) {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val itemsJson = prefs.getString("flutter.kim_memory_items_v1", "[]") ?: "[]"
            val existingArray = org.json.JSONArray(itemsJson)

            val newItems = mutableListOf<org.json.JSONObject>()
            val itemsList = payload["items"]
            if (itemsList is List<*>) {
                for (itemMap in itemsList) {
                    if (itemMap is Map<*, *>) {
                        @Suppress("UNCHECKED_CAST")
                        newItems.add(convertMapToJsonObject(itemMap as Map<String, Any?>))
                    }
                }
            } else {
                newItems.add(convertMapToJsonObject(payload))
            }

            // Prepend new items without overwriting index 0
            val combinedArray = org.json.JSONArray()
            for (newItem in newItems) {
                combinedArray.put(newItem)
            }
            for (i in 0 until existingArray.length()) {
                combinedArray.put(existingArray.getJSONObject(i))
            }

            prefs.edit().putString("flutter.kim_memory_items_v1", combinedArray.toString()).apply()
            syncWidgetNatively(prefs, combinedArray)

        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    private fun syncWidgetNatively(prefs: android.content.SharedPreferences, allItems: org.json.JSONArray) {
        try {
            val configStr = prefs.getString("flutter.kim_widget_config_v1", null)
            val cfg = if (configStr != null) try { org.json.JSONObject(configStr) } catch (_: Exception) { null } else null
            val maxItems = cfg?.optInt("maxItems", 3)?.coerceIn(1, 5) ?: 3
            val prioritizePinned = cfg?.optBoolean("prioritizePinned", true) ?: true
            val filterType = cfg?.optString("filterType", null)
            val filterTag = cfg?.optString("filterTag", null)?.lowercase()?.trim()
            val showTags = cfg?.optBoolean("showTags", true) ?: true

            val widgetPrefs = getSharedPreferences(KeepInMindWidgetProvider.PREFS_NAME, Context.MODE_PRIVATE)
            val oldStr = widgetPrefs.getString(KeepInMindWidgetProvider.KEY_PAYLOAD, null)
            val oldObj = if (oldStr != null) try { org.json.JSONObject(oldStr) } catch (_: Exception) { null } else null
            val addBtnLabel = oldObj?.optString("addBtnLabel", "+ Salva") ?: "+ Salva"
            val viewAllBtnLabel = oldObj?.optString("viewAllBtnLabel", "Visualizza tutto →") ?: "Visualizza tutto →"
            val emptyLabel = oldObj?.optString("emptyLabel", null)

            val candidates = mutableListOf<org.json.JSONObject>()
            for (i in 0 until allItems.length()) {
                val item = allItems.getJSONObject(i)
                val type = item.optString("type", "text")
                val tagsArr = item.optJSONArray("tags")
                val tagsList = mutableListOf<String>()
                if (tagsArr != null) {
                    for (t in 0 until tagsArr.length()) tagsList.add(tagsArr.optString(t).lowercase().trim())
                }
                if (!filterTag.isNullOrBlank() && !tagsList.contains(filterTag)) continue
                if (!filterType.isNullOrBlank() && type != filterType) continue
                candidates.add(item)
            }

            if (prioritizePinned) {
                candidates.sortWith { a, b ->
                    val pA = a.optBoolean("isPinned", false)
                    val pB = b.optBoolean("isPinned", false)
                    if (pA != pB) (if (pA) -1 else 1) else b.optString("createdAt", "").compareTo(a.optString("createdAt", ""))
                }
            }

            val widgetItemsArray = org.json.JSONArray()
            val limit = candidates.size.coerceAtMost(maxItems)
            for (i in 0 until limit) {
                val orig = candidates[i]
                val row = org.json.JSONObject().apply {
                    put("id", orig.optString("id", ""))
                    put("type", orig.optString("type", "text"))
                    put("title", orig.optString("title", ""))
                    val d = orig.optString("domain", "")
                    val fn = orig.optString("fileName", "")
                    val c = orig.optString("content", "")
                    put("subtitle", if (d.isNotEmpty()) d else if (fn.isNotEmpty()) fn else if (c.length > 70) "${c.substring(0, 70)}…" else c)
                    val fp = orig.optString("filePath", "")
                    if (fp.isNotEmpty()) put("filePath", fp)
                    val mt = orig.optString("mimeType", "")
                    if (mt.isNotEmpty()) put("mimeType", mt)
                    put("isPinned", orig.optBoolean("isPinned", false))
                    put("createdAt", orig.optString("createdAt", ""))
                    val tArr = orig.optJSONArray("tags")
                    if (tArr != null && tArr.length() > 0) {
                        val strList = (0 until tArr.length().coerceAtMost(3)).map { tArr.optString(it).replaceFirstChar { ch -> ch.uppercase() } }
                        put("tags", strList.joinToString(" · "))
                    }
                }
                widgetItemsArray.put(row)
            }

            val payloadObj = org.json.JSONObject().apply {
                put("maxItems", maxItems)
                put("prioritizePinned", prioritizePinned)
                put("showTags", showTags)
                put("totalCount", allItems.length())
                put("items", widgetItemsArray)
                put("countLabel", "Ultimi $limit/$maxItems")
                put("subtitleLabel", "Memoria locale · ${allItems.length()} salvati")
                put("addBtnLabel", addBtnLabel)
                put("viewAllBtnLabel", viewAllBtnLabel)
                if (emptyLabel != null) put("emptyLabel", emptyLabel)
            }

            widgetPrefs.edit().putString(KeepInMindWidgetProvider.KEY_PAYLOAD, payloadObj.toString()).apply()
            KeepInMindWidgetProvider.updateAllWidgets(applicationContext)
        } catch (_: Exception) {}
    }


    private fun convertMapToJsonObject(map: Map<String, Any?>): org.json.JSONObject {
        val json = org.json.JSONObject()
        val id = java.util.UUID.randomUUID().toString()
        val createdAt = java.time.Instant.now().toString()
        
        json.put("id", id)
        json.put("createdAt", createdAt)
        json.put("isPinned", false)
        
        val text = (map["text"] as? String ?: "").trim()
        val subject = (map["subject"] as? String ?: "").trim()
        val filePath = map["filePath"] as? String
        val fileName = map["fileName"] as? String
        val mimeType = map["mimeType"] as? String
        val fileSizeBytes = map["fileSizeBytes"] as? Number
        val source = map["source"] as? String ?: "Share to Self"
        
        json.put("source", source)
        
        if (filePath != null && filePath.isNotEmpty()) {
            val lowerMime = (mimeType ?: "").lowercase()
            val lowerName = (fileName ?: "").lowercase()
            val isImg = lowerMime.startsWith("image/") || 
                        lowerName.let { it.endsWith(".jpg") || it.endsWith(".png") || it.endsWith(".jpeg") || it.endsWith(".webp") }
            val isAudio = lowerMime.startsWith("audio/") ||
                        lowerName.let { it.endsWith(".m4a") || it.endsWith(".mp3") || it.endsWith(".wav") || it.endsWith(".aac") || it.endsWith(".ogg") }
            json.put("type", if (isImg) "image" else "file")
            json.put("filePath", filePath)
            json.put("fileName", fileName)
            json.put("mimeType", mimeType)
            if (fileSizeBytes != null) json.put("fileSizeBytes", fileSizeBytes.toLong())
            
            val resolvedTitle = if (subject.isNotEmpty()) subject else (if (text.isNotEmpty()) text else (fileName ?: "Allegato"))
            json.put("title", resolvedTitle)
            json.put("content", text)
            
            val tagsArray = org.json.JSONArray()
            tagsArray.put(if (isImg) "immagine" else if (isAudio) "audio" else "file")
            json.put("tags", tagsArray)
        } else {
            val urlRegex = Regex("""https?://[^\s]+""")
            val match = urlRegex.find(text)
            if (match != null) {
                val url = match.value
                val domain = try {
                    java.net.URI(url).host?.removePrefix("www.")
                } catch (_: Exception) {
                    null
                }
                val remainingText = text.replace(url, "").trim()
                val title = when {
                    subject.isNotEmpty() -> subject
                    remainingText.isNotEmpty() -> {
                        val firstLine = remainingText.split("\n").first().trim()
                        if (firstLine.length > 60) "${firstLine.substring(0, 59)}…" else firstLine
                    }
                    !domain.isNullOrEmpty() -> domain
                    else -> url
                }
                json.put("type", "link")
                json.put("url", url)
                if (!domain.isNullOrEmpty()) json.put("domain", domain)
                json.put("title", title)
                json.put("content", text)
                val tagsArray = org.json.JSONArray().apply { put("link") }
                json.put("tags", tagsArray)
            } else {
                json.put("type", "text")
                val title = if (subject.isNotEmpty()) {
                    subject
                } else {
                    val firstLine = text.split("\n").first().trim()
                    if (firstLine.length > 60) "${firstLine.substring(0, 59)}…" else firstLine
                }
                json.put("title", if (title.isEmpty()) "Nota" else title)
                json.put("content", text)
                val tagsArray = org.json.JSONArray().apply { put("nota") }
                json.put("tags", tagsArray)
            }
        }
        return json
    }

    override fun onDestroy() {
        stopAndReleasePlayer()
        stopAndReleaseRecorder()
        super.onDestroy()
    }
}

class LocalVideoViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        @Suppress("UNCHECKED_CAST")
        val creationParams = args as? Map<String, Any?>
        val filePath = creationParams?.get("filePath") as? String ?: ""
        return LocalVideoPlatformView(context, filePath)
    }
}

class LocalVideoPlatformView(context: Context, filePath: String) : PlatformView {
    private val container = FrameLayout(context)
    private val videoView = VideoView(context)

    init {
        val params = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT,
            Gravity.CENTER
        )
        videoView.layoutParams = params
        container.addView(videoView)

        if (filePath.isNotEmpty()) {
            try {
                val controller = MediaController(context)
                controller.setAnchorView(videoView)
                videoView.setMediaController(controller)
                videoView.setVideoURI(Uri.fromFile(File(filePath)))
                videoView.setOnPreparedListener { mp ->
                    mp.isLooping = false
                    videoView.seekTo(1)
                }
            } catch (_: Exception) {
            }
        }
    }

    override fun getView(): View = container

    override fun dispose() {
        try {
            videoView.stopPlayback()
        } catch (_: Exception) {
        }
    }
}


