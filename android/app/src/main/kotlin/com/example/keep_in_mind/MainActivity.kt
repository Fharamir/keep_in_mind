package com.example.keep_in_mind

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val shareChannelName = "com.example.keep_in_mind/share"
    private val shareStreamName = "com.example.keep_in_mind/share_stream"
    private val widgetChannelName = "com.example.keep_in_mind/widget"

    private var initialPayload: Map<String, Any?>? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        initialPayload = extractPayloadFromIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val payload = extractPayloadFromIntent(intent)
        if (payload != null) {
            eventSink?.success(payload)
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
}

