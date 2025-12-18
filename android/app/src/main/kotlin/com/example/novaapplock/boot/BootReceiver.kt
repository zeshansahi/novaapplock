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
        if (action == Intent.ACTION_BOOT_COMPLETED || action == Intent.ACTION_LOCKED_BOOT_COMPLETED) {
            try {
                val serviceIntent = Intent(context, MonitoringService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
                Log.d("BootReceiver", "MonitoringService started on boot")
            } catch (e: Exception) {
                Log.e("BootReceiver", "Failed to start MonitoringService on boot: ${e.message}", e)
            }
        }
    }
}
