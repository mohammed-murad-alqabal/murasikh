package com.example.murassikh_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

class MurassikhWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.murassikh_widget_layout)

            val verseText = widgetData.getString("verse_text", "أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ")
            val sourceText = widgetData.getString("source_text", "سورة الرعد: ٢٨")

            views.setTextViewText(R.id.verse_text, verseText)
            views.setTextViewText(R.id.source_text, sourceText)
            appWidgetManager.updateAppWidget(widgetId, views)

            // جلب مباشر من الخادم في الخلفية (Native Fetch)
            thread {
                try {
                    val url = URL("http://192.168.1.106:8000/api/v1/home/verse")
                    val conn = url.openConnection() as HttpURLConnection
                    conn.requestMethod = "POST"
                    conn.setRequestProperty("Content-Type", "application/json")
                    conn.doOutput = true
                    
                    val payload = """{"signal_source": "widget", "confidence": 0.0}"""
                    conn.outputStream.use { os -> os.write(payload.toByteArray(Charsets.UTF_8)) }
                    
                    if (conn.responseCode == 200) {
                        val responseStr = conn.inputStream.bufferedReader().use { it.readText() }
                        val json = JSONObject(responseStr)
                        val newVerse = json.optString("verse", "")
                        val newSource = json.optString("source", "")
                        
                        if (newVerse.isNotEmpty()) {
                            widgetData.edit().putString("verse_text", newVerse).putString("source_text", newSource).apply()
                            views.setTextViewText(R.id.verse_text, newVerse)
                            views.setTextViewText(R.id.source_text, newSource)
                            appWidgetManager.updateAppWidget(widgetId, views)
                        }
                    }
                    conn.disconnect()
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
    }
}
