package com.example.lembretes_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

class LembreteAmigoWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId, widgetData)
        }
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        widgetData: SharedPreferences
    ) {
        val views = RemoteViews(context.packageName, R.layout.lembrete_amigo_widget_layout)
        val jsonString = widgetData.getString("reminders", null)
        val role = widgetData.getString("widget_role", "elderly") ?: "elderly"
        val updatedAt = widgetData.getString("widget_updated_at", null)
        val updatedLabel = if (!updatedAt.isNullOrBlank() && updatedAt.length >= 16) {
            "Atualizado às ${updatedAt.substring(11, 16)}"
        } else {
            "Últimos dados disponíveis"
        }
        views.setTextViewText(R.id.widget_updated, updatedLabel)
        views.setOnClickPendingIntent(
            R.id.widget_container,
            launchIntent(context, null, role)
        )

        val itemIds = intArrayOf(
            R.id.widget_item_1,
            R.id.widget_item_2,
            R.id.widget_item_3
        )
        itemIds.forEach { views.setViewVisibility(it, View.GONE) }

        if (jsonString.isNullOrEmpty()) {
            views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
            views.setViewVisibility(R.id.widget_list, View.GONE)
            appWidgetManager.updateAppWidget(appWidgetId, views)
            return
        }

        try {
            val reminders = JSONArray(jsonString)
            if (reminders.length() == 0) {
                views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                views.setViewVisibility(R.id.widget_list, View.GONE)
                appWidgetManager.updateAppWidget(appWidgetId, views)
                return
            }
            views.setViewVisibility(R.id.widget_empty, View.GONE)
            views.setViewVisibility(R.id.widget_list, View.VISIBLE)

            for (i in 0 until minOf(reminders.length(), 3)) {
                val reminder = reminders.getJSONObject(i)
                val title = reminder.optString("title", "")
                val hour = reminder.optInt("hour", 0)
                val minute = reminder.optInt("minute", 0)
                val category = reminder.optString("category", "personalizado")
                val status = effectiveStatus(
                    reminder.optString("status", "proximo"),
                    hour,
                    minute
                )
                val timeStr = String.format("%02d:%02d", hour, minute)
                val icon = getCategoryIcon(category)
                val statusLabel = getStatusLabel(status)

                val itemId = when (i) {
                    0 -> R.id.widget_item_1
                    1 -> R.id.widget_item_2
                    else -> R.id.widget_item_3
                }
                val timeId = when (i) {
                    0 -> R.id.widget_time_1
                    1 -> R.id.widget_time_2
                    else -> R.id.widget_time_3
                }
                val iconId = when (i) {
                    0 -> R.id.widget_icon_1
                    1 -> R.id.widget_icon_2
                    else -> R.id.widget_icon_3
                }
                val titleId = when (i) {
                    0 -> R.id.widget_title_1
                    1 -> R.id.widget_title_2
                    else -> R.id.widget_title_3
                }

                views.setTextViewText(timeId, timeStr)
                views.setTextViewText(iconId, icon)
                views.setTextViewText(
                    titleId,
                    if (statusLabel.isEmpty()) title else "$statusLabel • $title"
                )
                val color = when (status) {
                    "agora" -> Color.rgb(255, 235, 59)
                    "atrasado" -> Color.rgb(255, 205, 210)
                    "adiado" -> Color.rgb(255, 224, 178)
                    else -> Color.WHITE
                }
                views.setTextColor(timeId, color)
                views.setTextColor(titleId, color)
                views.setViewVisibility(itemId, View.VISIBLE)
                views.setOnClickPendingIntent(
                    itemId,
                    launchIntent(context, reminder.optString("id", ""), role)
                )
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        } catch (e: Exception) {
            views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
            views.setViewVisibility(R.id.widget_list, View.GONE)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun getCategoryIcon(category: String): String {
        return when (category) {
            "medicacao" -> "\uD83D\uDC8A"
            "refeicao", "refeicoes" -> "\uD83C\uDF7D"
            "exercicio" -> "\uD83C\uDFC3"
            "agua", "hidratacao" -> "\uD83D\uDCA7"
            "bem_estar" -> "\uD83D\uDE0A"
            else -> "\u23F0"
        }
    }

    private fun getStatusLabel(status: String): String {
        return when (status) {
            "agora" -> "AGORA"
            "atrasado" -> "ATRASADO"
            "adiado" -> "ADIADO"
            else -> ""
        }
    }

    private fun effectiveStatus(storedStatus: String, hour: Int, minute: Int): String {
        if (storedStatus == "adiado") return storedStatus
        val calendar = java.util.Calendar.getInstance()
        val nowMinutes = calendar.get(java.util.Calendar.HOUR_OF_DAY) * 60 +
            calendar.get(java.util.Calendar.MINUTE)
        val difference = hour * 60 + minute - nowMinutes
        return when {
            difference < -4 -> "atrasado"
            difference <= 1 -> "agora"
            else -> "proximo"
        }
    }

    private fun launchIntent(context: Context, reminderId: String?, role: String) =
        HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.Builder()
                .scheme("lembreteamigo")
                .authority("widget")
                .appendQueryParameter("id", reminderId ?: "")
                .appendQueryParameter("role", role)
                .build()
        )
}
