package com.example.novaapplock

import android.app.ActivityManager
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val USAGE_STATS_CHANNEL = "com.example.novaapplock/usage_stats"
    private val OVERLAY_CHANNEL = "com.example.novaapplock/overlay"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Usage stats channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, USAGE_STATS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkUsageStatsPermission" -> {
                    result.success(checkUsageStatsPermission())
                }
                "requestUsageStatsPermission" -> {
                    requestUsageStatsPermission()
                    result.success(null)
                }
                "openUsageStatsSettings" -> {
                    openUsageStatsSettings()
                    result.success(null)
                }
                "getForegroundApp" -> {
                    result.success(getForegroundApp())
                }
                "getAppName" -> {
                    val packageName = call.argument<String>("packageName")
                    result.success(getAppName(packageName ?: ""))
                }
                else -> result.notImplemented()
            }
        }
        
        // Overlay channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OVERLAY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "showOverlay" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    val appName = call.argument<String>("appName") ?: "App"
                    showOverlay(packageName, appName)
                    result.success(null)
                }
                "hideOverlay" -> {
                    hideOverlay()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun showOverlay(packageName: String, appName: String) {
        val intent = Intent(this, OverlayService::class.java).apply {
            putExtra("packageName", packageName)
            putExtra("appName", appName)
        }
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }
    
    private fun hideOverlay() {
        val intent = Intent(this, OverlayService::class.java)
        stopService(intent)
    }

    private fun checkUsageStatsPermission(): Boolean {
        val appContext = applicationContext
        val time = System.currentTimeMillis()
        val usageStatsManager = appContext.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        
        try {
            val stats = usageStatsManager.queryUsageStats(
                UsageStatsManager.INTERVAL_DAILY,
                time - 1000 * 60,
                time
            )
            return stats != null && stats.isNotEmpty()
        } catch (e: Exception) {
            return false
        }
    }

    private fun requestUsageStatsPermission() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
        startActivity(intent)
    }

    private fun openUsageStatsSettings() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
        startActivity(intent)
    }

    private fun getForegroundApp(): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            return null
        }

        try {
            val usageStatsManager = applicationContext.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val time = System.currentTimeMillis()
            
            // Query usage stats for last 2 seconds (very recent)
            val stats = usageStatsManager.queryUsageStats(
                UsageStatsManager.INTERVAL_BEST,
                time - 2000, // Last 2 seconds
                time
            )

            if (stats != null && stats.isNotEmpty()) {
                var mostRecent: UsageStats? = null
                var mostRecentTime: Long = 0

                for (usageStats in stats) {
                    // Use lastTimeUsed for all versions
                    val checkTime = usageStats.lastTimeUsed
                    
                    if (checkTime > mostRecentTime) {
                        mostRecent = usageStats
                        mostRecentTime = checkTime
                    }
                }

                return mostRecent?.packageName
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error getting foreground app: ${e.message}")
        }

        // Fallback to ActivityManager for recent tasks (deprecated but works on older versions)
        try {
            val activityManager = applicationContext.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP_MR1) {
                @Suppress("DEPRECATION")
                val tasks = activityManager.getRunningTasks(1)
                if (tasks.isNotEmpty() && tasks[0].topActivity != null) {
                    return tasks[0].topActivity?.packageName
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error getting foreground app from ActivityManager: ${e.message}")
        }

        return null
    }

    private fun getAppName(packageName: String): String {
        return try {
            val pm = packageManager
            val appInfo: ApplicationInfo = pm.getApplicationInfo(packageName, 0)
            pm.getApplicationLabel(appInfo).toString()
        } catch (e: PackageManager.NameNotFoundException) {
            packageName
        } catch (e: Exception) {
            packageName
        }
    }
}
