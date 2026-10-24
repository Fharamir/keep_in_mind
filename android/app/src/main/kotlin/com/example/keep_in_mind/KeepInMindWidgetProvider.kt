package com.example.keep_in_mind

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject

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
            views.setOnClickPendingIntent(
                R.id.widget_title,
                PendingIntent.getActivity(context, 0, openAppIntent, flags)
            )

            val quickAddIntent = Intent(context, MainActivity::class.java).apply {
                action = ACTION_QUICK_ADD
                this.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            views.setOnClickPendingIntent(
                R.id.widget_add_btn,
                PendingIntent.getActivity(context, 999, quickAddIntent, flags)
            )

            val rowIds = intArrayOf(
                R.id.widget_item_1,
                R.id.widget_item_2,
                R.id.widget_item_3,
                R.id.widget_item_4,
                R.id.widget_item_5
            )
            for (rowId in rowIds) views.setViewVisibility(rowId, View.GONE)

            if (rawJson.isNullOrEmpty()) {
                views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                views.setTextViewText(R.id.widget_count, "0 elementi")
                appWidgetManager.updateAppWidget(appWidgetId, views)
                return
            }

            try {
                val root = JSONObject(rawJson)
                val maxItems = root.optInt("maxItems", 3).coerceIn(1, 5)
                val items = root.optJSONArray("items") ?: JSONArray()
                val count = items.length().coerceAtMost(maxItems)
                views.setTextViewText(R.id.widget_count, "Ultimi $count/$maxItems")

                if (count == 0) {
                    views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.widget_empty, View.GONE)
                    for (i in 0 until count) {
                        val item = items.getJSONObject(i)
                        val id = item.optString("id", "")
                        val typeLabel = item.optString("typeLabel", "Nota")
                        val title = item.optString("title", "Senza titolo")
                        val subtitle = item.optString("subtitle", "")
                        val pin = if (item.optBoolean("isPinned", false)) "📌 " else "• "
                        val display = if (subtitle.isNotEmpty() && subtitle != title) {
                            "$pin[$typeLabel] $title — $subtitle"
                        } else {
                            "$pin[$typeLabel] $title"
                        }

                        val rowViewId = rowIds[i]
                        views.setViewVisibility(rowViewId, View.VISIBLE)
                        views.setTextViewText(rowViewId, display)

                        val itemIntent = Intent(context, MainActivity::class.java).apply {
                            action = ACTION_OPEN_ITEM
                            putExtra(EXTRA_ITEM_ID, id)
                            this.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        }
                        views.setOnClickPendingIntent(
                            rowViewId,
                            PendingIntent.getActivity(context, 100 + i, itemIntent, flags)
                        )
                    }
                }
            } catch (_: Exception) {
                views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
