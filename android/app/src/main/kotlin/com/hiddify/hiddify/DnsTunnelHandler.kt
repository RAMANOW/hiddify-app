package com.hiddify.hiddify

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * The "DNS قطعی" tab's platform side (channel com.ramanow.ramanvpn/dnstunnel): start / stop / test
 * the DNS-tunnel engines of [DnsTunnelCore], their status and log, and the phone's own resolvers.
 */
class DnsTunnelHandler : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var context: Context? = null
    // a pool, so stop / cancel are never queued behind a long start or test
    private val worker = Executors.newCachedThreadPool()
    private val main = Handler(Looper.getMainLooper())

    companion object {
        const val channelName = "com.ramanow.ramanvpn/dnstunnel"
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

    private fun background(result: MethodChannel.Result, block: () -> Any?) {
        worker.execute {
            val value = try {
                Result.success(block())
            } catch (t: Throwable) {
                Result.failure(t)
            }
            main.post {
                value.fold(
                    { result.success(it) },
                    { result.error("dnstunnel", it.message ?: it.javaClass.simpleName, null) },
                )
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val ctx = context ?: return result.error("no_context", "not attached", null)
        when (call.method) {
            "available" -> background(result) { DnsTunnelCore.available(ctx) }
            "systemDns" -> background(result) { DnsTunnelCore.systemDns(ctx) }
            "start" -> {
                val spec = call.argument<String>("spec") ?: return result.error("args", "spec", null)
                background(result) { DnsTunnelCore.start(ctx, spec) }
            }
            "stop" -> background(result) { DnsTunnelCore.stop(); true }
            "status" -> background(result) { DnsTunnelCore.status() }
            "logs" -> background(result) { DnsTunnelCore.logs() }
            "test" -> {
                val spec = call.argument<String>("spec") ?: return result.error("args", "spec", null)
                background(result) { DnsTunnelCore.test(ctx, spec) }
            }
            "cancelTest" -> background(result) { DnsTunnelCore.cancelTest(); true }
            else -> result.notImplemented()
        }
    }
}
