package com.example.viewsys

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.WindowManager
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.os.Build
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterActivity(){
    private val handler =Handler(Looper.getMainLooper())

    //Runs every 10 seconds to keep kiosk mode enforced
    private val kioskRunnable = object : Runnable{
        override fun run(){
            enterImmersiveMode()
            AppWatchdogReceiver.schedule(this@MainActivity)
            handler.postDelayed(this, 10_000L)
        }
    }

     override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        // Register the native ExoPlayer view so Flutter can use it via AndroidView
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "native_video_player",
            NativePlayerFactory(flutterEngine.dartExecutor.binaryMessenger)
        )
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // ── Screen always on ──────────────────────────────────────────
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.addFlags(WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
        window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
        window.addFlags(WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD)

        // ── Full immersive / kiosk mode ───────────────────────────────
        enterImmersiveMode()

        // ── Start background keep-alive service ───────────────────────
        val serviceIntent = Intent(this, KeepAliveService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }

        // ── Schedule crash-recovery watchdog alarm ────────────────────
        AppWatchdogReceiver.schedule(this)

        // ── Start periodic kiosk reassert loop ────────────────────────
        handler.postDelayed(kioskRunnable, 10_000L)
    }

    override fun onResume() {
        super.onResume()
        enterImmersiveMode()
        AppWatchdogReceiver.schedule(this)
    }

     override fun onPause() {
        super.onPause()
        // Reschedule — if app never resumes, watchdog fires and restarts it
        AppWatchdogReceiver.schedule(this)
    }

    override fun onDestroy() {
        handler.removeCallbacks(kioskRunnable)
        // Do NOT cancel watchdog here — we want it to restart the app if destroyed
        super.onDestroy()
    }


    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) enterImmersiveMode()
    }

     // Block back button — users cannot exit the signage player
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // Intentionally empty
    }

    private fun enterImmersiveMode() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.let { controller ->
                controller.hide(
                    WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars()
                )
                controller.systemBarsBehavior =
                    WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_FULLSCREEN
            )
        }
    }
}

