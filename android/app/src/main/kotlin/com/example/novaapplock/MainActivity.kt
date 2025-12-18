package com.example.novaapplock

import android.app.ActivityManager
import android.app.AppOpsManager
import android.app.usage.UsageEvents
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
    companion object {
        @JvmStatic var pendingLockPackage: String? = null
        @JvmStatic var pendingLockAppName: String? = null
        @JvmStatic var pendingLockTimestamp: Long? = null
    }
    private val PENDING_LOCK_TTL_MS = 15000L
    private var flutterEngine: FlutterEngine? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // Check intent for lock overlay trigger
        handleIntent(intent)
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }
    
    private fun handleIntent(intent: Intent?) {
        if (intent?.getBooleanExtra("show_lock_overlay", false) == true) {
            val packageName = intent.getStringExtra("locked_package_name")
            val appName = intent.getStringExtra("locked_app_name") ?: "App"
            android.util.Log.d("MainActivity", "Intent received to show lock overlay for: $packageName")
            
            // Store in SharedPreferences for Flutter to read on resume
            if (packageName != null) {
                val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                prefs.edit().apply {
                    putBoolean("flutter.show_lock_overlay_pending", true)
                    putString("flutter.locked_package_name", packageName)
                    putString("flutter.locked_app_name", appName)
                    putLong("flutter.locked_timestamp", System.currentTimeMillis())
                    apply()
                }
                android.util.Log.d("MainActivity", "Stored lock overlay info in SharedPreferences")
            }
        } else {
            // User opened the app normally; clear any stale pending lock.
            pendingLockPackage = null
            pendingLockAppName = null
            pendingLockTimestamp = null
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.edit().apply {
                remove("flutter.show_lock_overlay_pending")
                remove("flutter.locked_package_name")
                remove("flutter.locked_app_name")
                remove("flutter.locked_timestamp")
                apply()
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        this.flutterEngine = flutterEngine
        
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
                "startMonitoringService" -> {
                    startMonitoringService()
                    result.success(null)
                }
                "stopMonitoringService" -> {
                    stopMonitoringService()
                    result.success(null)
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
                "markUnlocked" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        MonitoringService.markAppUnlocked(packageName)
                        android.util.Log.d("MainActivity", "Marked $packageName as unlocked")
                    }
                    result.success(null)
                }
                "bringToFront" -> {
                    bringAppToFront()
                    result.success(null)
                }
                "openAutoStartSettings" -> {
                    result.success(openAutoStartSettings())
                }
                "markUnlocked" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    markUnlocked(packageName)
                    result.success(null)
                }
                "openApp" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    val opened = openApp(packageName)
                    result.success(opened)
                }
                "moveToBackground" -> {
                    result.success(moveToBackground())
                }
                "getPendingLock" -> {
                    try {
                        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                        val fromStaticPackage = pendingLockPackage
                        val fromStaticApp = pendingLockAppName
                        val fromStaticTimestamp = pendingLockTimestamp ?: 0L
                        val hasPrefPending = prefs.getBoolean("flutter.show_lock_overlay_pending", false)
                        val prefPackage = prefs.getString("flutter.locked_package_name", null)
                        val prefApp = prefs.getString("flutter.locked_app_name", null)
                        val prefTimestamp = prefs.getLong("flutter.locked_timestamp", 0L)

                        val packageName: String?
                        val appName: String?
                        val timestamp: Long

                        if (!fromStaticPackage.isNullOrEmpty()) {
                            packageName = fromStaticPackage
                            appName = fromStaticApp ?: "App"
                            timestamp = fromStaticTimestamp
                        } else if (hasPrefPending && !prefPackage.isNullOrEmpty()) {
                            packageName = prefPackage
                            appName = prefApp ?: "App"
                            timestamp = prefTimestamp
                        } else {
                            packageName = null
                            appName = null
                            timestamp = 0L
                        }

                        if (packageName != null) {
                            val now = System.currentTimeMillis()
                            val isFresh = timestamp > 0L && now - timestamp <= PENDING_LOCK_TTL_MS

                            pendingLockPackage = null
                            pendingLockAppName = null
                            pendingLockTimestamp = null
                            prefs.edit().apply {
                                remove("flutter.show_lock_overlay_pending")
                                remove("flutter.locked_package_name")
                                remove("flutter.locked_app_name")
                                remove("flutter.locked_timestamp")
                                apply()
                            }

                            if (isFresh) {
                                result.success(mapOf("packageName" to packageName, "appName" to (appName ?: "App")))
                            } else {
                                android.util.Log.w("MainActivity", "Discarded stale pending lock for $packageName")
                                result.success(null)
                            }
                        } else {
                            result.success(null)
                        }
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "Error getting pending lock: ${e.message}", e)
                        result.error("pending_lock_error", e.message, null)
                    }
                }
                "clearPendingLock" -> {
                    clearPendingLock()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun clearPendingLock() {
        pendingLockPackage = null
        pendingLockAppName = null
        pendingLockTimestamp = null
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefs.edit().apply {
            remove("flutter.show_lock_overlay_pending")
            remove("flutter.locked_package_name")
            remove("flutter.locked_app_name")
            remove("flutter.locked_timestamp")
            apply()
        }
        android.util.Log.d("MainActivity", "Cleared pending lock state")
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

    private fun markUnlocked(packageName: String) {
        try {
            val intent = Intent(this, MonitoringService::class.java).apply {
                action = MonitoringService.ACTION_MARK_UNLOCKED
                putExtra(MonitoringService.EXTRA_PACKAGE_NAME, packageName)
                // Also track current unlocked foreground
                putExtra("current_unlocked_foreground", packageName)
            }
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            android.util.Log.d("MainActivity", "markUnlocked sent for $packageName")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error sending markUnlocked: ${e.message}", e)
        }
    }

    private fun openApp(packageName: String): Boolean {
        return try {
            val intent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP
                )
            }
            if (intent != null) {
                startActivity(intent)
                android.util.Log.d("MainActivity", "Launched app $packageName")
                true
            } else {
                android.util.Log.w("MainActivity", "No launch intent for $packageName")
                false
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error launching $packageName: ${e.message}", e)
            false
        }
    }
    
    private fun moveToBackground(): Boolean {
        return try {
            moveTaskToBack(true)
            android.util.Log.d("MainActivity", "Moved task to background after unlock")
            true
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error moving to background: ${e.message}", e)
            false
        }
    }
    
    private fun hideOverlay() {
        val intent = Intent(this, OverlayService::class.java)
        stopService(intent)
    }

    private fun startMonitoringService() {
        val intent = Intent(this, MonitoringService::class.java)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        android.util.Log.d("MainActivity", "MonitoringService start requested")
    }

    private fun stopMonitoringService() {
        val intent = Intent(this, MonitoringService::class.java)
        stopService(intent)
        android.util.Log.d("MainActivity", "MonitoringService stop requested")
    }

    private fun bringAppToFront() {
        try {
            // Prefer moving our existing task to front to avoid re-creating the activity
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            activityManager.moveTaskToFront(taskId, 0)
            android.util.Log.d("MainActivity", "bringToFront via moveTaskToFront")
        } catch (e: Exception) {
            android.util.Log.w("MainActivity", "moveTaskToFront failed: ${e.message}, using reorderToFront")
            try {
                val intent = Intent(this, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                }
                startActivity(intent)
                android.util.Log.d("MainActivity", "bringToFront via reorderToFront")
            } catch (inner: Exception) {
                android.util.Log.e("MainActivity", "Error bringing app to front: ${inner.message}", inner)
            }
        }
    }

    private fun openAutoStartSettings(): Boolean {
        val intents = listOf(
            Intent().setClassName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity"),
            Intent("miui.intent.action.OP_AUTO_START"),
            Intent().setClassName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity"),
            Intent().setClassName("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity"),
            Intent().setClassName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity"),
            Intent().setClassName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity"),
            Intent().setClassName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"),
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = android.net.Uri.parse("package:$packageName")
            },
            Intent(Settings.ACTION_SETTINGS)
        )

        intents.forEach { intent ->
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                if (intent.resolveActivity(packageManager) != null) {
                    startActivity(intent)
                    android.util.Log.d("MainActivity", "Opened auto-start settings via $intent")
                    return true
                }
            } catch (_: Exception) {
                // Try next intent
            }
        }
        return false
    }

    private fun checkUsageStatsPermission(): Boolean {
        val appContext = applicationContext
        val time = System.currentTimeMillis()
        val usageStatsManager = appContext.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        
        // Stronger permission check using AppOpsManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            try {
                val appOps = appContext.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
                val mode = appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    android.os.Process.myUid(),
                    appContext.packageName
                )
                if (mode != AppOpsManager.MODE_ALLOWED) {
                    android.util.Log.w("MainActivity", "Usage stats AppOps check failed: mode=$mode")
                    return false
                }
            } catch (e: Exception) {
                android.util.Log.w("MainActivity", "AppOps check failed: ${e.message}")
            }
        }

        try {
            // Try to query usage stats - if permission is granted, this will return data
            val stats = usageStatsManager.queryUsageStats(
                UsageStatsManager.INTERVAL_BEST,
                time - (60 * 1000), // Last 1 minute
                time
            )
            val hasPermission = stats != null
            android.util.Log.d("MainActivity", "Usage stats permission check: $hasPermission (stats count: ${stats?.size ?: 0})")
            return hasPermission
        } catch (e: SecurityException) {
            android.util.Log.w("MainActivity", "Usage stats permission denied: ${e.message}")
            return false
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error checking usage stats permission: ${e.message}")
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
            android.util.Log.w("MainActivity", "Android version too old for usage stats")
            return null
        }

        // First check if permission is granted
        if (!checkUsageStatsPermission()) {
            android.util.Log.w("MainActivity", "Usage stats permission not granted")
            return null
        }

        try {
            val usageStatsManager = applicationContext.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val time = System.currentTimeMillis()

            // Primary: use UsageEvents to get the latest foreground/resume event in the last few seconds
            val eventWindowStart = time - 10000 // last 10s
            val events = usageStatsManager.queryEvents(eventWindowStart, time)
            val event = UsageEvents.Event()
            var latestPackageFromEvents: String? = null
            var latestEventTime = 0L
            var eventCount = 0

            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                eventCount++
                if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND ||
                    event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                    if (event.timeStamp > latestEventTime) {
                        latestEventTime = event.timeStamp
                        latestPackageFromEvents = event.packageName
                    }
                }
            }

            if (latestPackageFromEvents != null) {
                val diff = time - latestEventTime
                android.util.Log.d("MainActivity", "Foreground (events): $latestPackageFromEvents (diff ${diff}ms, events scanned=$eventCount)")
                return latestPackageFromEvents
            } else {
                android.util.Log.d("MainActivity", "No recent MOVE_TO_FOREGROUND events (scanned $eventCount), fallback to UsageStats")
            }
            
            // Fallback: UsageStats (guard against stale data)
            val stats = usageStatsManager.queryUsageStats(
                UsageStatsManager.INTERVAL_BEST,
                time - 60000, // Last 1 minute
                time
            )

            android.util.Log.d("MainActivity", "Query returned ${stats?.size ?: 0} stats")

            if (stats != null && stats.isNotEmpty()) {
                var mostRecent: UsageStats? = null
                var mostRecentTime: Long = 0

                // List of system apps/launchers to skip
                val skipPackages = listOf(
                    "com.example.novaapplock", // Our own app
                    "com.google.android.apps.nexuslauncher", // Launchers
                    "com.android.launcher",
                    "com.android.launcher2",
                    "com.android.launcher3",
                    "com.miui.home",
                    "com.huawei.android.launcher",
                    "com.samsung.android.app.launcher",
                    "com.oneplus.launcher",
                    "com.google.android.permissioncontroller", // Permission dialogs
                    "com.android.packageinstaller", // Package installer
                    "com.google.android.packageinstaller",
                    "com.android.systemui", // System UI
                    "com.google.android.systemui"
                )

                for (usageStats in stats) {
                    val packageName = usageStats.packageName
                    if (skipPackages.contains(packageName)) continue

                    val checkTime = usageStats.lastTimeUsed
                    if (checkTime > mostRecentTime) {
                        mostRecent = usageStats
                        mostRecentTime = checkTime
                    }
                }

                val packageName = mostRecent?.packageName
                if (packageName != null) {
                    val timeDiff = time - mostRecentTime
                    // Treat stale data (> 10s old) as unknown to avoid wrong locks
                    if (timeDiff > 10000) {
                        android.util.Log.w("MainActivity", "Most recent app is stale (${timeDiff}ms), returning null")
                        return null
                    }
                    android.util.Log.d("MainActivity", "Foreground app detected: $packageName (last used: ${mostRecentTime}, time diff: ${timeDiff}ms)")
                    return packageName
                } else {
                    android.util.Log.w("MainActivity", "No recent app found")
                }
            } else {
                android.util.Log.w("MainActivity", "No usage stats returned")
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error getting foreground app: ${e.message}", e)
        }

        // Fallback: Try to get from ActivityManager (works on older Android versions)
        try {
            val activityManager = applicationContext.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP_MR1) {
                @Suppress("DEPRECATION")
                val tasks = activityManager.getRunningTasks(1)
                if (tasks.isNotEmpty() && tasks[0].topActivity != null) {
                    val packageName = tasks[0].topActivity?.packageName
                    android.util.Log.d("MainActivity", "Using ActivityManager fallback: $packageName")
                    return packageName
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error getting foreground app from ActivityManager: ${e.message}", e)
        }

        android.util.Log.w("MainActivity", "Could not determine foreground app")
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
