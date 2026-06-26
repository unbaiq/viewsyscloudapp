package com.example.viewsys

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import androidx.core.app.NotificationCompat

class KeepAliveService : Service() {

    private val CHANNEL_ID = "viewsys_keepalive"
    private val NOTIFICATION_ID = 1001

    private var wakeLock: PowerManager.WakeLock? = null
    private val handler = Handler(Looper.getMainLooper())

    // Check every 30 seconds if the main app is still alive
    private val monitorRunnable = object : Runnable {
        override fun run() {
            // Reschedule watchdog alarm — confirms service is still running
            AppWatchdogReceiver.schedule(this@KeepAliveService)
            handler.postDelayed(this, 30_000L)
        }
    }

    override fun onCreate() {
        super.onCreate()

        createNotificationChannel()

        // Build the persistent notification (required for foreground services on Android 8+)
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getActivity(this, 0, notificationIntent, pendingFlags)

        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Viewsys Player")
            .setContentText("Signage player is running")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentIntent(pendingIntent)
            .setOngoing(true)           // Cannot be dismissed by the user
            .setSilent(true)            // No sound or vibration
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        // Promote to foreground service — Android will NOT kill this process aggressively
        startForeground(NOTIFICATION_ID, notification)

        // Acquire a partial wake lock so the CPU stays awake even if screen is off
        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "viewsys::KeepAliveWakeLock"
        )
        wakeLock?.acquire(60 * 60 * 1000L) // Acquire for max 1 hour at a time

        // Start watchdog + monitoring loop
        AppWatchdogReceiver.schedule(this)
        handler.post(monitorRunnable)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // START_STICKY — if Android kills the service, it will be restarted automatically
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(monitorRunnable)
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        super.onDestroy()

        // Self-restart — if service is destroyed, restart it immediately
        val restartIntent = Intent(applicationContext, KeepAliveService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(restartIntent)
        } else {
            startService(restartIntent)
        }
    }

    // Service does not support binding
    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Viewsys Keep Alive",
                NotificationManager.IMPORTANCE_LOW  // Low importance = silent, no heads-up
            ).apply {
                description = "Keeps the signage player running in the background"
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}