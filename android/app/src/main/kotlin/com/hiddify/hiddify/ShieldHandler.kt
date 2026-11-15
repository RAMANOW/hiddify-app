package com.hiddify.hiddify

import android.content.Context
import android.content.Intent
import android.media.RingtoneManager
import android.net.ConnectivityManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Raman Shield's platform pieces: the system proxy (for Shield's upstream proxy), the system VPN
 * settings (always-on VPN), and a sound and/or vibration when Shield's connection changes.
 */
class ShieldHandler : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var context: Context? = null

    companion object {
        const val channelName = "com.ramanow.ramanvpn/shield"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, channelName).also { it.setMethodCallHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val ctx = context ?: return result.error("no_context", "not attached", null)
        when (call.method) {
            "systemProxy" -> {
                try {
                    val cm = ctx.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                    val proxy = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) cm.defaultProxy else null
                    val host = proxy?.host ?: System.getProperty("http.proxyHost")
                    val port = proxy?.port ?: System.getProperty("http.proxyPort")?.toIntOrNull()
                    if (host.isNullOrBlank() || port == null || port <= 0) {
                        result.success(null)
                    } else {
                        result.success(mapOf("host" to host, "port" to port))
                    }
                } catch (e: Exception) {
                    result.success(null)
                }
            }
            "openVpnSettings" -> {
                try {
                    val intent = Intent(android.provider.Settings.ACTION_VPN_SETTINGS)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    ctx.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.success(false)
                }
            }
            "statusFeedback" -> {
                val sound = call.argument<Boolean>("sound") ?: false
                val vibrate = call.argument<Boolean>("vibrate") ?: false
                if (sound) playSound(ctx)
                if (vibrate) vibrate(ctx)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun playSound(ctx: Context) {
        try {
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION) ?: return
            RingtoneManager.getRingtone(ctx, uri)?.play()
        } catch (_: Exception) {
        }
    }

    @Suppress("DEPRECATION")
    private fun vibrate(ctx: Context) {
        try {
            val vibrator: Vibrator? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                (ctx.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
            } else {
                ctx.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }
            if (vibrator == null || !vibrator.hasVibrator()) return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createOneShot(250, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                vibrator.vibrate(250)
            }
        } catch (_: Exception) {
        }
    }
}
