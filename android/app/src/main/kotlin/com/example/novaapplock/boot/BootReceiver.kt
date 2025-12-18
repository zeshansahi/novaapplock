package com.example.novaapplock.boot

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.example.novaapplock.MonitoringService

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == Intent.ACTION_LOCKED_BOOT_COMPLETED ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val monitoringEnabled = prefs.getBoolean("flutter.monitoring_enabled", false)
            if (!monitoringEnabled) {
                Log.d("BootReceiver", "Monitoring disabled, skipping auto-start ($action)")
                return
            }
            try {
                val serviceIntent = Intent(context, MonitoringService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
                Log.d("BootReceiver", "MonitoringService start requested from $action")
            } catch (e: Exception) {
                Log.e("BootReceiver", "Failed to start MonitoringService on $action: ${e.message}", e)
            }
        }
    }
}
