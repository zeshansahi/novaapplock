package com.example.novaapplock

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.annotation.RequiresApi
import androidx.core.app.NotificationCompat

class OverlayService : Service() {
    private var overlayView: View? = null
    private var windowManager: WindowManager? = null
    private var isForegroundService = false

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
    }

    @RequiresApi(Build.VERSION_CODES.M)
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Always bring Flutter UI to front; native overlay disabled
        val packageName = intent?.getStringExtra("packageName") ?: ""
        val appName = intent?.getStringExtra("appName") ?: "App"

        try {
            // Persist pending lock info so Flutter can render the overlay once the app comes to foreground
            MainActivity.pendingLockPackage = packageName
            MainActivity.pendingLockAppName = appName
            MainActivity.pendingLockTimestamp = System.currentTimeMillis()
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.edit().apply {
                putBoolean("flutter.show_lock_overlay_pending", true)
                putString("flutter.locked_package_name", packageName)
                putString("flutter.locked_app_name", appName)
                putLong("flutter.locked_timestamp", System.currentTimeMillis())
                apply()
            }

            val launchIntent = packageManager.getLaunchIntentForPackage("com.example.novaapplock")?.apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra("show_lock_overlay", true)
                putExtra("locked_package_name", packageName)
                putExtra("locked_app_name", appName)
            }
            if (launchIntent != null) {
                startActivity(launchIntent)
                android.util.Log.d("OverlayService", "Launching app to show Flutter lock overlay for $packageName")
            } else {
                android.util.Log.e("OverlayService", "Launch intent null for com.example.novaapplock")
            }
        } catch (e: Exception) {
            android.util.Log.e("OverlayService", "Error launching app: ${e.message}", e)
        }

        stopSelf()
        return START_NOT_STICKY
    }

    // Native overlay UI removed; Flutter overlay handles PIN

    private fun ensureForegroundNotification(appName: String) {
        if (isForegroundService) return

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Nova App Lock")
            .setContentText("$appName is locked")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        // For Android 14+ (API 34+), use foregroundServiceType
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        isForegroundService = true
    }

    private fun hideOverlay(stopService: Boolean = true) {
        overlayView?.let {
            windowManager?.removeView(it)
            overlayView = null
        }
        if (isForegroundService) {
            stopForeground(true)
            isForegroundService = false
        }
        if (stopService) {
            stopSelf()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        android.util.Log.d("OverlayService", "onDestroy called")
        hideOverlay(stopService = false)
        super.onDestroy()
    }
    
    override fun onTaskRemoved(rootIntent: Intent?) {
        android.util.Log.d("OverlayService", "onTaskRemoved called - keeping service alive")
        // Don't stop the service when task is removed - keep overlay showing
        // This ensures overlay persists even when app is swiped from recent apps
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Overlay Lock Screen",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows a persistent notification while app lock overlay is active"
            }

            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    companion object {
        private const val CHANNEL_ID = "nova_overlay_channel"
        private const val NOTIFICATION_ID = 1001
    }
}
