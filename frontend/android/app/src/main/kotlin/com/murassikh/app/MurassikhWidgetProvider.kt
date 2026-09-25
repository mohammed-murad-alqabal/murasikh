package com.murassikh.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class MurassikhWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.murassikh_widget_layout)
            views.setTextViewText(
                R.id.verse_text,
                widgetData.getString("verse_text", "أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ"),
            )
            views.setTextViewText(
                R.id.source_text,
                widgetData.getString("source_text", "سورة الرعد: ٢٨"),
            )
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
