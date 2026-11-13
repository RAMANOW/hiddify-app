package com.hiddify.hiddify

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Raman VPN's disguise icon: the launcher entry is one of several activity-aliases of
 * MainActivity (see AndroidManifest.xml), and exactly one of them is enabled at a time.
 */
class LauncherIconHandler : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var context: Context? = null

    companion object {
        const val channelName = "com.ramanow.ramanvpn/launcher_icon"
        val aliases = listOf("Default", "Calculator", "Weather", "Notes", "Clock")
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

    private fun component(ctx: Context, alias: String) =
        ComponentName(ctx.packageName, "${MainActivity::class.java.`package`!!.name}.Launcher$alias")

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val ctx = context ?: return result.error("no_context", "not attached", null)
        val pm = ctx.packageManager
        when (call.method) {
            "get" -> {
                val enabled = aliases.firstOrNull { alias ->
                    when (pm.getComponentEnabledSetting(component(ctx, alias))) {
                        PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
                        // never switched: the manifest's own value, on for Default only
                        PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> alias == "Default"
                        else -> false
                    }
                } ?: "Default"
                result.success(enabled)
            }
            "set" -> {
                val target = call.argument<String>("icon") ?: "Default"
                if (target !in aliases) return result.error("bad_icon", "unknown icon $target", null)
                try {
                    // enable the new one first, so the app always has a launcher entry
                    pm.setComponentEnabledSetting(
                        component(ctx, target),
                        PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                        PackageManager.DONT_KILL_APP,
                    )
                    for (alias in aliases) {
                        if (alias == target) continue
                        pm.setComponentEnabledSetting(
                            component(ctx, alias),
                            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                            PackageManager.DONT_KILL_APP,
                        )
                    }
                    result.success(true)
                } catch (e: Exception) {
                    result.error("set_failed", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }
}
