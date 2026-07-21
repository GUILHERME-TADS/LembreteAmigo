package com.example.lembretes_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.util.TypedValue
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
        val theme = widgetData.getString("widget_theme", "classic_blue") ?: "classic_blue"
        val fontSizeStr = widgetData.getString("widget_font_size", "normal") ?: "normal"

        val updatedAt = widgetData.getString("widget_updated_at", null)
        val updatedLabel = if (!updatedAt.isNullOrBlank() && updatedAt.length >= 16) {
            "Atualizado às ${updatedAt.substring(11, 16)}"
        } else {
            "Últimos dados"
        }
        views.setTextViewText(R.id.widget_updated, updatedLabel)
        views.setOnClickPendingIntent(
            R.id.widget_container,
            launchIntent(context, null, role)
        )

        // Configurar botões de ação rápida (Falar e Rádio)
        views.setOnClickPendingIntent(
            R.id.widget_btn_talk,
            launchActionIntent(context, "talk", role)
        )
        views.setOnClickPendingIntent(
            R.id.widget_btn_radio,
            launchActionIntent(context, "radio", role)
        )

        // Aplicar Tema Visual (Azul Clássico, Alto Contraste ou Modo Noturno)
        val isHighContrast = theme == "high_contrast_yellow"
        val isDarkMode = theme == "dark_mode"

        val bgRes = when (theme) {
            "high_contrast_yellow" -> R.drawable.widget_bg_high_contrast
            "dark_mode" -> R.drawable.widget_bg_dark_mode
            else -> R.drawable.widget_bg_classic_blue
        }
        val cardRes = when (theme) {
            "high_contrast_yellow" -> R.drawable.widget_card_high_contrast
            "dark_mode" -> R.drawable.widget_card_dark_mode
            else -> R.drawable.widget_card_classic_blue
        }
        val btnRes = when (theme) {
            "high_contrast_yellow" -> R.drawable.widget_btn_high_contrast
            "dark_mode" -> R.drawable.widget_btn_dark
            else -> R.drawable.widget_btn_classic
        }

        views.setInt(R.id.widget_container, "setBackgroundResource", bgRes)
        views.setInt(R.id.widget_btn_talk, "setBackgroundResource", btnRes)
        views.setInt(R.id.widget_btn_radio, "setBackgroundResource", btnRes)

        val mainTextColor = if (isHighContrast) Color.BLACK else Color.WHITE
        val subTextColor = if (isHighContrast) Color.DKGRAY else Color.argb(217, 255, 255, 255)
        val btnTextColor = if (isDarkMode) Color.WHITE else if (isHighContrast) Color.YELLOW else Color.BLACK

        views.setTextColor(R.id.widget_title, mainTextColor)
        views.setTextColor(R.id.widget_updated, subTextColor)
        views.setTextColor(R.id.widget_empty, mainTextColor)
        views.setTextColor(R.id.widget_btn_talk_text, btnTextColor)
        views.setTextColor(R.id.widget_btn_radio_text, btnTextColor)

        // Tamanhos de fonte
        val baseSizeDelta = when (fontSizeStr) {
            "grande" -> 2f
            "extra_grande" -> 4f
            else -> 0f
        }
        views.setTextViewTextSize(R.id.widget_title, TypedValue.COMPLEX_UNIT_SP, 15f + baseSizeDelta)
        views.setTextViewTextSize(R.id.widget_empty, TypedValue.COMPLEX_UNIT_SP, 14f + baseSizeDelta)

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

                views.setInt(itemId, "setBackgroundResource", cardRes)
                views.setTextViewText(timeId, timeStr)
                views.setTextViewText(iconId, icon)
                views.setTextViewText(
                    titleId,
                    if (statusLabel.isEmpty()) title else "$statusLabel • $title"
                )

                views.setTextViewTextSize(timeId, TypedValue.COMPLEX_UNIT_SP, 15f + baseSizeDelta)
                views.setTextViewTextSize(iconId, TypedValue.COMPLEX_UNIT_SP, 16f + baseSizeDelta)
                views.setTextViewTextSize(titleId, TypedValue.COMPLEX_UNIT_SP, 15f + baseSizeDelta)

                val itemColor = when (status) {
                    "agora" -> if (isHighContrast) Color.rgb(200, 0, 0) else Color.rgb(255, 235, 59)
                    "atrasado" -> if (isHighContrast) Color.rgb(180, 0, 0) else Color.rgb(255, 205, 210)
                    "adiado" -> if (isHighContrast) Color.rgb(150, 100, 0) else Color.rgb(255, 224, 178)
                    else -> mainTextColor
                }
                views.setTextColor(timeId, itemColor)
                views.setTextColor(titleId, itemColor)
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
            "medicacao" -> "💊"
            "refeicao", "refeicoes" -> "🍽️"
            "exercicio" -> "🏃"
            "agua", "hidratacao" -> "💧"
            "bem_estar" -> "😊"
            else -> "⏰"
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

    private fun launchActionIntent(context: Context, action: String, role: String) =
        HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.Builder()
                .scheme("lembreteamigo")
                .authority("widget")
                .appendQueryParameter("action", action)
                .appendQueryParameter("role", role)
                .build()
        )
}
