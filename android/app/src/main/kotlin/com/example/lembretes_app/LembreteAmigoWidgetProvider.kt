package com.example.lembretes_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
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

        if (jsonString.isNullOrEmpty()) {
            views.setViewVisibility(R.id.widget_empty, android.view.View.VISIBLE)
            views.setViewVisibility(R.id.widget_list, android.view.View.GONE)
            appWidgetManager.updateAppWidget(appWidgetId, views)
            return
        }

        try {
            val reminders = JSONArray(jsonString)
            views.setViewVisibility(R.id.widget_empty, android.view.View.GONE)
            views.setViewVisibility(R.id.widget_list, android.view.View.VISIBLE)

            for (i in 0 until minOf(reminders.length(), 3)) {
                val reminder = reminders.getJSONObject(i)
                val title = reminder.optString("title", "")
                val hour = reminder.optInt("hour", 0)
                val minute = reminder.optInt("minute", 0)
                val category = reminder.optString("category", "personalizado")
                val timeStr = String.format("%02d:%02d", hour, minute)
                val icon = getCategoryIcon(category)

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
                views.setTextViewText(titleId, title)
                views.setViewVisibility(itemId, android.view.View.VISIBLE)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        } catch (e: Exception) {
            views.setViewVisibility(R.id.widget_empty, android.view.View.VISIBLE)
            views.setViewVisibility(R.id.widget_list, android.view.View.GONE)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun getCategoryIcon(category: String): String {
        return when (category) {
            "medicacao" -> "\uD83D\uDC8A"
            "refeicao" -> "\uD83C\uDF7D"
            "exercicio" -> "\uD83C\uDFC3"
            "agua" -> "\uD83D\uDCA7"
            "bem_estar" -> "\uD83D\uDE0A"
            else -> "\u23F0"
        }
    }
}
