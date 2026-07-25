package com.kaher.siyak

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createDefaultNotificationChannel()
    }

    /**
     * Creates the high-importance channel referenced by the FCM
     * `default_notification_channel_id` manifest metadata. Android O+ drops
     * notifications posted to a non-existent channel, so this must exist before
     * the first message arrives. Idempotent — safe to call every launch.
     */
    private fun createDefaultNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "siyaq_general",
                "عام",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "إشعارات سياق العامة"
                enableVibration(true)
            }
            getSystemService(NotificationManager::class.java)
                ?.createNotificationChannel(channel)
        }
    }
}
