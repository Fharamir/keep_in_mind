package com.example.keep_in_mind

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.view.View
import android.os.Build
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

class KeepInMindWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            updateWidget(context, appWidgetManager, id)
        }
    }

    companion object {
        const val PREFS_NAME = "keep_in_mind_widget_prefs"
        const val KEY_PAYLOAD = "widget_payload_json"
        const val ACTION_OPEN_ITEM = "com.example.keep_in_mind.ACTION_OPEN_ITEM"
        const val ACTION_QUICK_ADD = "com.example.keep_in_mind.ACTION_QUICK_ADD"
        const val EXTRA_ITEM_ID = "extra_item_id"

        fun updateAllWidgets(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, KeepInMindWidgetProvider::class.java)
            )
            for (id in ids) {
                updateWidget(context, manager, id)
            }
        }

        private fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.keep_in_mind_widget)
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val rawJson = prefs.getString(KEY_PAYLOAD, null)

            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                this.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val openAppPending = PendingIntent.getActivity(context, 0, openAppIntent, flags)
            views.setOnClickPendingIntent(R.id.widget_title_box, openAppPending)
            views.setOnClickPendingIntent(R.id.widget_logo, openAppPending)
            views.setOnClickPendingIntent(R.id.widget_view_all_btn, openAppPending)

            val quickAddIntent = Intent(context, MainActivity::class.java).apply {
                action = ACTION_QUICK_ADD
                this.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            views.setOnClickPendingIntent(
                R.id.widget_add_btn,
                PendingIntent.getActivity(context, 999, quickAddIntent, flags)
            )

            // Mutable PendingIntent template required on API 31+ for item fill-in intents
            val mutableFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val itemTemplateIntent = Intent(context, MainActivity::class.java).apply {
                action = ACTION_OPEN_ITEM
                this.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val itemTemplatePending = PendingIntent.getActivity(
                context,
                500,
                itemTemplateIntent,
                mutableFlags
            )
            views.setPendingIntentTemplate(R.id.widget_list_view, itemTemplatePending)

            if (rawJson.isNullOrEmpty()) {
                views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                views.setViewVisibility(R.id.widget_list_view, View.GONE)
                views.setTextViewText(R.id.widget_count, "Ultimi 0/3")
                views.setTextViewText(R.id.widget_total_subtitle, "Memoria locale · 0 salvati")
                appWidgetManager.updateAppWidget(appWidgetId, views)
                return
            }

            try {
                val root = JSONObject(rawJson)
                val maxItems = root.optInt("maxItems", 3).coerceIn(1, 5)
                val items = root.optJSONArray("items") ?: JSONArray()
                val count = items.length().coerceAtMost(maxItems)
                val totalCount = root.optInt("totalCount", items.length())

                val countLabel = root.optString("countLabel", "Ultimi $count/$maxItems")
                val subtitleLabel = root.optString(
                    "subtitleLabel",
                    "Memoria locale · $totalCount ${if (totalCount == 1) "salvato" else "salvati"}"
                )
                val addBtnLabel = root.optString("addBtnLabel", "+ Salva")
                val viewAllBtnLabel = root.optString("viewAllBtnLabel", "Visualizza tutto →")
                val emptyLabel = root.optString("emptyLabel", null)

                views.setTextViewText(R.id.widget_count, countLabel)
                views.setTextViewText(R.id.widget_total_subtitle, subtitleLabel)
                views.setTextViewText(R.id.widget_add_btn, addBtnLabel)
                views.setTextViewText(R.id.widget_view_all_btn, viewAllBtnLabel)
                if (!emptyLabel.isNullOrEmpty()) {
                    views.setTextViewText(R.id.widget_empty, emptyLabel)
                }

                if (count == 0) {
                    views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_list_view, View.GONE)
                } else {
                    views.setViewVisibility(R.id.widget_empty, View.GONE)
                    views.setViewVisibility(R.id.widget_list_view, View.VISIBLE)

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val builder = RemoteViews.RemoteCollectionItems.Builder()
                            .setHasStableIds(true)
                            .setViewTypeCount(1)
                        for (i in 0 until count) {
                            val item = items.getJSONObject(i)
                            val rowView = buildRowRemoteView(context, item)
                            builder.addItem(i.toLong(), rowView)
                        }
                        views.setRemoteAdapter(R.id.widget_list_view, builder.build())
                    }
                }
            } catch (_: Exception) {
                views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                views.setViewVisibility(R.id.widget_list_view, View.GONE)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun buildRowRemoteView(
            context: Context,
            item: JSONObject
        ): RemoteViews {
            val row = RemoteViews(context.packageName, R.layout.keep_in_mind_widget_row)
            val id = item.optString("id", "")
            val title = item.optString("title", "Senza titolo")
            val isPinned = item.optBoolean("isPinned", false)
            val type = item.optString("type", "text")
            val mimeType = item.optString("mimeType", "").lowercase()
            val filePath = item.optString("filePath", "")

            val rawSubtitle = item.optString("subtitle", "").ifEmpty {
                item.optString("domain", "").ifEmpty {
                    item.optString("fileName", "").ifEmpty {
                        item.optString("content", "")
                    }
                }
            }.replace("\n", " ").trim()

            val tagsDisplay = extractTagsDisplay(item, type, mimeType)
            val dateDisplay = formatWidgetDate(item.optString("createdAt", ""))

            val displayTitle = if (isPinned) "📌 $title" else title
            row.setTextViewText(R.id.row_title, displayTitle)

            if (rawSubtitle.isNotEmpty() && rawSubtitle != title) {
                row.setViewVisibility(R.id.row_subtitle, View.VISIBLE)
                row.setTextViewText(R.id.row_subtitle, rawSubtitle)
            } else {
                row.setViewVisibility(R.id.row_subtitle, View.GONE)
            }

            if (tagsDisplay.isNotEmpty()) {
                row.setViewVisibility(R.id.row_tags, View.VISIBLE)
                row.setTextViewText(R.id.row_tags, tagsDisplay)
                row.setTextColor(R.id.row_tags, colorForType(type, mimeType))
            } else {
                row.setViewVisibility(R.id.row_tags, View.GONE)
            }

            row.setTextViewText(R.id.row_date, dateDisplay)

            val bitmap = if (type == "image" || mimeType.startsWith("image/")) {
                loadScaledBitmap(filePath, 96)
            } else null

            if (bitmap != null) {
                row.setViewVisibility(R.id.row_img, View.VISIBLE)
                row.setViewVisibility(R.id.row_icon, View.GONE)
                row.setImageViewBitmap(R.id.row_img, bitmap)
            } else {
                row.setViewVisibility(R.id.row_img, View.GONE)
                row.setViewVisibility(R.id.row_icon, View.VISIBLE)
                val iconEmoji = when {
                    type == "image" || mimeType.startsWith("image/") -> "🖼️"
                    mimeType.startsWith("audio/") -> "🎙️"
                    type == "link" -> "🔗"
                    type == "file" -> "📁"
                    else -> "📝"
                }
                row.setTextViewText(R.id.row_icon, iconEmoji)
            }

            val fillInIntent = Intent().apply {
                putExtra(EXTRA_ITEM_ID, id)
            }
            row.setOnClickFillInIntent(R.id.row_root, fillInIntent)

            return row
        }

        private fun extractTagsDisplay(item: JSONObject, type: String, mimeType: String): String {
            val rawTags = item.opt("tags")
            if (rawTags is String && rawTags.isNotEmpty()) {
                return rawTags.replace("#", "")
            }
            if (rawTags is JSONArray && rawTags.length() > 0) {
                val list = mutableListOf<String>()
                for (i in 0 until rawTags.length().coerceAtMost(3)) {
                    val t = rawTags.optString(i, "").replace("#", "").trim()
                    if (t.isNotEmpty()) {
                        list.add(t.replaceFirstChar { it.uppercase() })
                    }
                }
                if (list.isNotEmpty()) return list.joinToString(" · ")
            }
            return when {
                type == "image" || mimeType.startsWith("image/") -> "Immagine"
                mimeType.startsWith("audio/") -> "Audio"
                type == "link" -> "Link"
                type == "file" -> "File"
                else -> "Nota"
            }
        }

        private fun colorForType(type: String, mimeType: String): Int {
            return when {
                type == "image" || mimeType.startsWith("image/") -> Color.parseColor("#AA00FF")
                mimeType.startsWith("audio/") -> Color.parseColor("#FF3D00")
                type == "link" -> Color.parseColor("#2962FF")
                type == "file" -> Color.parseColor("#00796B")
                else -> Color.parseColor("#FF8F00")
            }
        }

        private fun formatWidgetDate(isoString: String): String {
            if (isoString.isEmpty()) return ""
            return try {
                val instant = Instant.parse(if (isoString.endsWith("Z")) isoString else "${isoString}Z")
                val formatter = DateTimeFormatter.ofPattern("dd/MM HH:mm")
                    .withZone(ZoneId.systemDefault())
                formatter.format(instant)
            } catch (_: Exception) {
                if (isoString.length >= 16) {
                    val m = isoString.substring(5, 7)
                    val d = isoString.substring(8, 10)
                    val t = isoString.substring(11, 16)
                    "$d/$m $t"
                } else ""
            }
        }

        private fun loadScaledBitmap(filePath: String, maxSize: Int): Bitmap? {
            if (filePath.isEmpty()) return null
            return try {
                val file = File(filePath)
                if (!file.exists()) return null

                val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeFile(file.absolutePath, bounds)
                if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

                var sampleSize = 1
                while (bounds.outWidth / sampleSize > maxSize * 2 &&
                    bounds.outHeight / sampleSize > maxSize * 2
                ) {
                    sampleSize *= 2
                }

                val opts = BitmapFactory.Options().apply { inSampleSize = sampleSize }
                val decoded = BitmapFactory.decodeFile(file.absolutePath, opts) ?: return null
                Bitmap.createScaledBitmap(decoded, maxSize, maxSize, true)
            } catch (_: Exception) {
                null
            }
        }
    }
}
