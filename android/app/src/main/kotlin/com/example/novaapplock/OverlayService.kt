package com.example.novaapplock

import android.app.Service
import android.content.Intent
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

class OverlayService : Service() {
    private var overlayView: View? = null
    private var windowManager: WindowManager? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
    }

    @RequiresApi(Build.VERSION_CODES.M)
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val packageName = intent?.getStringExtra("packageName") ?: ""
        val appName = intent?.getStringExtra("appName") ?: "App"
        
        showOverlay(packageName, appName)
        return START_STICKY
    }

    @RequiresApi(Build.VERSION_CODES.M)
    private fun showOverlay(packageName: String, appName: String) {
        if (overlayView != null) {
            return // Already showing
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                WindowManager.LayoutParams.TYPE_PHONE
            },
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 0
            y = 0
        }

        // Create a simple lock screen view programmatically
        overlayView = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.BLACK)
            
            val textView = TextView(this@OverlayService).apply {
                text = "$appName is locked"
                setTextColor(Color.WHITE)
                textSize = 24f
                setPadding(0, 0, 0, 64)
            }
            
            val button = Button(this@OverlayService).apply {
                text = "Unlock (Temporary - PIN not implemented in native)"
                setOnClickListener {
                    hideOverlay()
                    // Send unlock event back to Flutter
                    sendBroadcast(Intent("com.example.novaapplock.UNLOCK").apply {
                        putExtra("packageName", packageName)
                    })
                }
            }
            
            addView(textView)
            addView(button)
        }

        windowManager?.addView(overlayView, params)
    }

    private fun hideOverlay() {
        overlayView?.let {
            windowManager?.removeView(it)
            overlayView = null
        }
        stopSelf()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        hideOverlay()
        super.onDestroy()
    }
}

