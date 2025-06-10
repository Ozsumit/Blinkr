package com.example.blinkr

import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "blink_reminder/overlay"
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "showOverlay" -> {
                    val duration = call.argument<Int>("duration") ?: 3000
                    if (canDrawOverlays()) {
                        showSystemOverlay(duration)
                        result.success(true)
                    } else {
                        // Request permission if not granted
                        requestOverlayPermission()
                        result.error("PERMISSION_DENIED", "Overlay permission not granted", null)
                    }
                }
                "checkPermission" -> {
                    result.success(canDrawOverlays())
                }
                "requestPermission" -> {
                    requestOverlayPermission()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun canDrawOverlays(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            val intent = android.content.Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                android.net.Uri.parse("package:$packageName")
            )
            startActivity(intent)
        }
    }

    private fun showSystemOverlay(duration: Int) {
        if (windowManager == null) {
            windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        }

        // Remove existing overlay if present
        removeOverlay()

        // Create main container with gradient background
        val overlayLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            setPadding(40, 100, 40, 40)
        }

        // Create gradient drawable for top-to-bottom fade effect
        val gradientDrawable = android.graphics.drawable.GradientDrawable(
            android.graphics.drawable.GradientDrawable.Orientation.TOP_BOTTOM,
            intArrayOf(
                Color.parseColor("#E6000000"), // Darker at top (90% opacity)
                Color.parseColor("#80000000"), // Medium in middle (50% opacity)
                Color.parseColor("#1A000000")  // Almost transparent at bottom (10% opacity)
            )
        )
        overlayLayout.background = gradientDrawable

        // Add some space at top
        val spacer = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                120
            )
        }
        overlayLayout.addView(spacer)

        // Add main "BLINK" text with animation
        val blinkTextView = TextView(this).apply {
            text = "BLINK"
            textSize = 48f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            alpha = 0f
            scaleX = 0.8f
            scaleY = 0.8f
        }
        overlayLayout.addView(blinkTextView)

        // Add subtitle
        val subtitleView = TextView(this).apply {
            text = ""
            textSize = 18f
            setTextColor(Color.parseColor("#CCFFFFFF"))
            gravity = Gravity.CENTER
            alpha = 0f
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = 20
                bottomMargin = 40
            }
        }
        overlayLayout.addView(subtitleView)

        // Add done button with rounded corners
        val dismissButton = Button(this).apply {
            text = "Done"
            textSize = 16f
            setTextColor(Color.WHITE)
            background = android.graphics.drawable.GradientDrawable().apply {
                shape = android.graphics.drawable.GradientDrawable.RECTANGLE
                cornerRadius = 25f
                setColor(Color.parseColor("#4CAF50"))
            }
            setPadding(40, 20, 40, 20)
            alpha = 1f
            setOnClickListener { removeOverlay() }
        }
        

        // Set layout parameters for full screen overlay
        val layoutParams = WindowManager.LayoutParams().apply {
            width = WindowManager.LayoutParams.MATCH_PARENT
            height = WindowManager.LayoutParams.MATCH_PARENT
            type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }
            flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
            format = PixelFormat.TRANSLUCENT
            gravity = Gravity.TOP
        }

        try {
            windowManager?.addView(overlayLayout, layoutParams)
            overlayView = overlayLayout

            // Animate elements in with fluid animations
            Handler(Looper.getMainLooper()).post {
                // Animate main text
                blinkTextView.animate()
                    .alpha(1f)
                    .scaleX(1f)
                    .scaleY(1f)
                    .setDuration(400)
                    .setInterpolator(android.view.animation.OvershootInterpolator())
                    .start()

                // Animate subtitle with delay
                subtitleView.animate()
                    .alpha(1f)
                    .setDuration(300)
                    .setStartDelay(150)
                    .start()

                // Animate button with delay
                dismissButton.animate()
                    .alpha(1f)
                    .setDuration(300)
                    .setStartDelay(300)
                    .start()
            }

            // Auto-remove after duration
            Handler(Looper.getMainLooper()).postDelayed({
                removeOverlay()
            }, duration.toLong())

        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun removeOverlay() {
        overlayView?.let { view ->
            try {
                windowManager?.removeView(view)
            } catch (e: Exception) {
                e.printStackTrace()
            }
            overlayView = null
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        removeOverlay()
    }
}