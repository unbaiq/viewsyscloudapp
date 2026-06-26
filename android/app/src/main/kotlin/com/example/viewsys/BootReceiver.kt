package com.example.viewsys

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return

        // All the broadcast actions that mean "device just started"
        val bootActions = setOf(
            Intent.ACTION_BOOT_COMPLETED,                    // Standard Android boot
            "android.intent.action.QUICKBOOT_POWERON",      // HTC / MediaTek devices
            "com.htc.intent.action.QUICKBOOT_POWERON",      // HTC specific
            Intent.ACTION_MY_PACKAGE_REPLACED,              // App just updated — relaunch
        )

        if (action in bootActions) {
            launchApp(context)
        }
    }

    private fun launchApp(context: Context) {
        try {
            // Wait 4 seconds — lets Android system services fully initialize after boot
            // before we try to start an Activity
            Thread.sleep(4_000)

            val launchIntent = Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
            context.startActivity(launchIntent)

            // Also start the keep-alive service immediately on boot
            val serviceIntent = Intent(context, KeepAliveService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }

        } catch (e: InterruptedException) {
            Thread.currentThread().interrupt()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}