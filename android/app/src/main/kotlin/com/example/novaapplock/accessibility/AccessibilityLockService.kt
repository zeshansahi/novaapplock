package com.example.novaapplock.accessibility

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import com.example.novaapplock.OverlayService
import com.example.novaapplock.R
import org.json.JSONArray

class AccessibilityLockService : AccessibilityService() {
    private var lastPackage: String? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        serviceInfo = serviceInfo.apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            notificationTimeout = 100
            flags = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS
        }
        Log.d("AccessibilityLock", "Service connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || event.packageName == null) return
        val pkg = event.packageName.toString()

        // Only act on window state changes to reduce noise
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        if (pkg == lastPackage) return
        lastPackage = pkg

        if (pkg == applicationContext.packageName) return

        val locked = getLockedApps()
        if (locked.contains(pkg)) {
            Log.d("AccessibilityLock", "Locked app detected via accessibility: $pkg")
            showOverlay(pkg, getAppName(pkg))
        }
    }

    override fun onInterrupt() {
        // No-op
    }

    private fun getLockedApps(): Set<String> {
        return try {
            val prefs: SharedPreferences = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val raw = prefs.getString("flutter.locked_apps_list", null) ?: return emptySet()
            val prefix = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu!"
            if (raw.startsWith(prefix)) {
                val json = raw.substring(prefix.length)
                val arr = JSONArray(json)
                (0 until arr.length()).map { arr.getString(it).trim() }.filter { it.isNotEmpty() }.toSet()
            } else {
                raw.split(",").map { it.trim() }.filter { it.isNotEmpty() }.toSet()
            }
        } catch (e: Exception) {
            Log.e("AccessibilityLock", "Error reading locked apps: ${e.message}", e)
            emptySet()
        }
    }

    private fun showOverlay(packageName: String, appName: String) {
        try {
            val intent = Intent(this, OverlayService::class.java).apply {
                putExtra("packageName", packageName)
                putExtra("appName", appName)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (e: Exception) {
            Log.e("AccessibilityLock", "Error starting overlay: ${e.message}", e)
        }
    }

    private fun getAppName(packageName: String): String {
        return try {
            val pm = packageManager
            val appInfo = pm.getApplicationInfo(packageName, 0)
            pm.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            packageName
        }
    }
}
