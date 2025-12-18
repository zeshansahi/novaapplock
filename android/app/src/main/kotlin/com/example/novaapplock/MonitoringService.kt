package com.example.novaapplock

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import org.json.JSONArray

class MonitoringService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var lastForeground: String? = null
    private var lastTriggered: String? = null
    private var currentUnlockedForeground: String? = null
    
    companion object {
        private const val CHANNEL_ID = "nova_monitor_channel"
        private const val NOTIFICATION_ID = 2001
        const val ACTION_MARK_UNLOCKED = "com.example.novaapplock.action.MARK_UNLOCKED"
        const val EXTRA_PACKAGE_NAME = "extra_package_name"
        
        // Track recently unlocked apps with timestamp to prevent immediate re-lock
        private val recentlyUnlockedApps = mutableMapOf<String, Long>()
        private const val UNLOCK_COOLDOWN_MS = 300000L // 5 minutes cooldown after unlock
        
        @JvmStatic
        fun markAppUnlocked(packageName: String) {
            recentlyUnlockedApps[packageName.lowercase()] = System.currentTimeMillis()
            Log.d("MonitoringService", "Marked $packageName as unlocked, cooldown active")
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_MARK_UNLOCKED) {
            val pkg = intent.getStringExtra(EXTRA_PACKAGE_NAME)
            if (!pkg.isNullOrEmpty()) {
                markAppUnlocked(pkg)
            }
            return START_STICKY
        }

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Nova App Lock")
            .setContentText("Monitoring locked apps")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        startForeground(NOTIFICATION_ID, notification)
        handler.post(checkRunnable)
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        stopForeground(true)
        // Try to restart if system kills service
        try {
            val restartIntent = Intent(applicationContext, MonitoringService::class.java).apply {
                setPackage(packageName)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(restartIntent)
            } else {
                startService(restartIntent)
            }
            Log.d("MonitoringService", "Service restart requested in onDestroy")
        } catch (e: Exception) {
            Log.e("MonitoringService", "Failed to restart service onDestroy: ${e.message}", e)
        }
        super.onDestroy()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Attempt to restart the service if the task is removed (e.g., swiped from recents)
        try {
            val restartIntent = Intent(applicationContext, MonitoringService::class.java)
            restartIntent.setPackage(packageName)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(restartIntent)
            } else {
                startService(restartIntent)
            }
            Log.d("MonitoringService", "Service restarted after task removed")
        } catch (e: Exception) {
            Log.e("MonitoringService", "Failed to restart service on task removed: ${e.message}", e)
        }
        super.onTaskRemoved(rootIntent)
    }

    private val checkRunnable = object : Runnable {
        override fun run() {
            try {
                val foreground = getForegroundApp()
                if (foreground != null) {
                    // If we switched away from a previously unlocked app, drop its cooldown entry
                    lastForeground?.let { prev ->
                        if (!foreground.equals(prev, ignoreCase = true)) {
                            recentlyUnlockedApps.remove(prev.lowercase())
                            if (currentUnlockedForeground != null && !foreground.equals(currentUnlockedForeground, ignoreCase = true)) {
                                currentUnlockedForeground = null
                            }
                        }
                    }

                    // Skip if within unlock cooldown
                    val now = System.currentTimeMillis()
                    val unlockedAt = recentlyUnlockedApps[foreground.lowercase()]
                    if (unlockedAt != null) {
                        val diff = now - unlockedAt
                        if (diff < UNLOCK_COOLDOWN_MS) {
                            Log.d("MonitoringService", "Skipping lock for $foreground within cooldown (${UNLOCK_COOLDOWN_MS - diff}ms left)")
                            handler.postDelayed(this, 300)
                            return
                        } else {
                            recentlyUnlockedApps.remove(foreground.lowercase())
                        }
                    } else {
                        // Clean out expired entries
                        val iterator = recentlyUnlockedApps.entries.iterator()
                        while (iterator.hasNext()) {
                            val entry = iterator.next()
                            if (now - entry.value > UNLOCK_COOLDOWN_MS) iterator.remove()
                        }
                    }
                    
                    // If this is the same app we just unlocked, keep it unlocked until user leaves
                    currentUnlockedForeground?.let { unlocked ->
                        if (foreground.equals(unlocked, ignoreCase = true)) {
                            lastForeground = foreground
                            handler.postDelayed(this, 300)
                            return
                        }
                    }

                    // If our app comes to foreground, hide any overlay (user is unlocking)
                    if (foreground == packageName) {
                        if (lastForeground != packageName) {
                            Log.d("MonitoringService", "Our app came to foreground, hiding overlay")
                            hideOverlay()
                            lastTriggered = null
                        }
                        lastForeground = foreground
                        handler.postDelayed(this, 1000)
                        return
                    }
                    
                    // Check if app lock is globally enabled
                    val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    val isLockEnabled = prefs.getBoolean("flutter.app_lock_enabled", false)
                    
                    if (!isLockEnabled) {
                        // If lock is disabled, ensure we respect that
                        if (lastTriggered != null) {
                            hideOverlay()
                            lastTriggered = null
                        }
                        lastForeground = foreground
                        handler.postDelayed(this, 300)
                        return
                    }
                    
                    // Check if foreground app is locked (case-insensitive)
                    val locked = getLockedApps()
                    val isLocked = locked.any { it.trim().lowercase() == foreground.trim().lowercase() }
                    
                    // Check if app was recently unlocked (cooldown period)
                    val unlockTime = recentlyUnlockedApps[foreground.lowercase()]
                    val isInCooldown = unlockTime != null && (System.currentTimeMillis() - unlockTime) < UNLOCK_COOLDOWN_MS
                    
                    if (isLocked && !isInCooldown) {
                        if (foreground != lastTriggered) {
                            Log.d("MonitoringService", "Locked app detected: $foreground, launching overlay")
                            showOverlay(foreground)
                            lastTriggered = foreground
                        }
                    } else if (isInCooldown) {
                        Log.d("MonitoringService", "App $foreground is in cooldown, skipping lock")
                        lastTriggered = null
                    } else if (foreground != lastForeground) {
                        // App changed to non-locked app, hide overlay and reset trigger
                        if (lastTriggered != null) {
                            Log.d("MonitoringService", "Switched to non-locked app, hiding overlay")
                            hideOverlay()
                        }
                        lastTriggered = null
                    }
                } else {
                    // No foreground app detected, hide overlay if showing
                    if (lastTriggered != null) {
                        hideOverlay()
                        lastTriggered = null
                    }
                }
                lastForeground = foreground
            } catch (e: Exception) {
                Log.e("MonitoringService", "Error in monitor loop: ${e.message}", e)
            } finally {
                handler.postDelayed(this, 300)
            }
        }
    }

    private fun getForegroundApp(): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) return null
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val time = System.currentTimeMillis()

        // Prefer events for recent foreground
        val events = usageStatsManager.queryEvents(time - 10000, time)
        val event = UsageEvents.Event()
        var latestPackage: String? = null
        var latestTime = 0L
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND ||
                event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                if (event.timeStamp > latestTime) {
                    latestTime = event.timeStamp
                    latestPackage = event.packageName
                }
            }
        }
        if (latestPackage != null) return latestPackage

        // Fallback to usage stats
        val stats = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_BEST,
            time - 60000,
            time
        ) ?: return null

        var mostRecent: UsageStats? = null
        var mostRecentTime = 0L
        for (us in stats) {
            if (us.lastTimeUsed > mostRecentTime) {
                mostRecent = us
                mostRecentTime = us.lastTimeUsed
            }
        }
        val pkg = mostRecent?.packageName
        val diff = time - mostRecentTime
        return if (pkg != null && diff <= 10000) pkg else null
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
            Log.e("MonitoringService", "Error reading locked apps: ${e.message}", e)
            emptySet()
        }
    }

    private fun showOverlay(packageName: String) {
        try {
            val appName = getAppName(packageName)
            
            // CRITICAL: Store pending lock in SharedPreferences BEFORE launching MainActivity
            // This ensures Flutter can read it even on cold start
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.edit().apply {
                putBoolean("flutter.show_lock_overlay_pending", true)
                putString("flutter.locked_package_name", packageName)
                putString("flutter.locked_app_name", appName)
                putLong("flutter.locked_timestamp", System.currentTimeMillis())
                commit() // Use commit() for synchronous write
            }
            Log.d("MonitoringService", "Stored pending lock in SharedPreferences: $packageName")
            
            // Launch MainActivity directly
            val intent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra("show_lock_overlay", true)
                putExtra("locked_package_name", packageName)
                putExtra("locked_app_name", appName)
            }
            startActivity(intent)
            Log.d("MonitoringService", "Started MainActivity overlay for $packageName ($appName)")
        } catch (e: Exception) {
            Log.e("MonitoringService", "Error showing overlay for $packageName: ${e.message}", e)
        }
    }
    
    private fun hideOverlay() {
        try {
            val intent = Intent(this, OverlayService::class.java)
            stopService(intent)
            Log.d("MonitoringService", "Requested to hide overlay")
        } catch (e: Exception) {
            Log.e("MonitoringService", "Error hiding overlay: ${e.message}", e)
        }
    }
    
    private fun getAppName(packageName: String): String {
        return try {
            val pm = packageManager
            val appInfo: android.content.pm.ApplicationInfo = pm.getApplicationInfo(packageName, 0)
            pm.getApplicationLabel(appInfo).toString()
        } catch (e: android.content.pm.PackageManager.NameNotFoundException) {
            packageName
        } catch (e: Exception) {
            Log.e("MonitoringService", "Error getting app name: ${e.message}")
            packageName
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Monitoring Service",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

}
