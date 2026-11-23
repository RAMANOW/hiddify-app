package com.hiddify.hiddify

import android.content.Context
import android.util.Log
import com.therealaleph.mhrv.Native
import org.json.JSONObject
import java.io.File
import java.net.InetSocketAddress
import java.net.Socket

/**
 * Raman VPN's Google Relay ("رله گوگل"): mhrv-rs (libmhrv_rs.so, MIT) run in this process,
 * listening on 127.0.0.1 only (HTTP on [HTTP_PORT], SOCKS5 on [SOCKS_PORT]). The Hiddify core
 * reaches it through a local profile with one socks outbound (lib/features/raman/relay), so the
 * VPN itself is the usual one. The relay's own connections to Google leave directly: the VPN
 * service always excludes this app's package from the tunnel, which also keeps them from looping.
 *
 * Nothing here runs unless the user starts the relay: the native library is loaded on first use.
 */
object RelayCore {
    private const val TAG = "RamanRelay"
    const val HTTP_PORT = 18085
    const val SOCKS_PORT = 18086

    // the Flutter app's prefs (shared_preferences keeps them under a "flutter." prefix)
    private const val PREFS = "FlutterSharedPreferences"
    private const val PREF_ACTIVE = "flutter.raman-relay-active"
    private const val PREF_CONFIG = "flutter.raman-relay-config"

    @Volatile
    private var handle = 0L
    private var dataDirSet = false
    private val logRing = ArrayDeque<String>()

    val running: Boolean get() = handle != 0L

    fun dataDir(ctx: Context): File = File(ctx.filesDir, "relay").apply { mkdirs() }

    /** True when libmhrv_rs.so loads; the reason otherwise. */
    @Synchronized
    fun load(ctx: Context): String? = try {
        if (!dataDirSet) {
            Native.setDataDir(dataDir(ctx).absolutePath)
            dataDirSet = true
        }
        null
    } catch (t: Throwable) {
        Log.w(TAG, "relay library not available", t)
        t.javaClass.simpleName + ": " + (t.message ?: "")
    }

    fun version(ctx: Context): String? = if (load(ctx) == null) runCatching { Native.version() }.getOrNull() else null

    /** Starts the relay with [configJson] (mhrv-rs JSON config); null when it listens, the error otherwise. */
    @Synchronized
    fun start(ctx: Context, configJson: String): String? {
        load(ctx)?.let { return it }
        if (handle != 0L) stopLocked()
        if (portOpen(SOCKS_PORT, 200) || portOpen(HTTP_PORT, 200)) {
            return "port $SOCKS_PORT/$HTTP_PORT busy"
        }
        val h = try {
            Native.startProxy(configJson)
        } catch (t: Throwable) {
            Log.w(TAG, "startProxy failed", t)
            return t.message ?: t.javaClass.simpleName
        }
        if (h == 0L) return "start failed: " + lastError()
        handle = h
        // the server binds on its own runtime: wait until the SOCKS port answers
        for (i in 0 until 30) {
            if (portOpen(SOCKS_PORT, 200)) return null
            Thread.sleep(100)
        }
        val err = lastError()
        stopLocked()
        return "not listening: $err"
    }

    @Synchronized
    fun stop() = stopLocked()

    private fun stopLocked() {
        val h = handle
        handle = 0L
        if (h != 0L) runCatching { Native.stopProxy(h) }.onFailure { Log.w(TAG, "stopProxy", it) }
    }

    fun stats(): String = if (handle == 0L) "" else runCatching { Native.statsJson(handle) }.getOrDefault("")

    /** New log lines joined into a ring of the last 300. */
    @Synchronized
    fun logs(): List<String> {
        if (dataDirSet) {
            val fresh = runCatching { Native.drainLogs() }.getOrDefault("")
            if (fresh.isNotEmpty()) {
                for (line in fresh.split('\n')) {
                    if (logRing.size >= 300) logRing.removeFirst()
                    logRing.addLast(line)
                }
            }
        }
        return logRing.toList()
    }

    private fun lastError(): String {
        val lines = logs()
        return lines.lastOrNull { it.contains("ERROR") || it.contains("error") || it.contains("failed") }
            ?: lines.lastOrNull() ?: ""
    }

    fun testSni(ctx: Context, ip: String, sni: String): String {
        load(ctx)?.let { return JSONObject().put("ok", false).put("error", it).toString() }
        return runCatching { Native.testSni(ip, sni) }
            .getOrElse { JSONObject().put("ok", false).put("error", it.message ?: "error").toString() }
    }

    fun portOpen(port: Int, timeoutMs: Int): Boolean = try {
        Socket().use { it.connect(InetSocketAddress("127.0.0.1", port), timeoutMs); true }
    } catch (_: Exception) {
        false
    }

    /**
     * Brings the relay back when the process starts again while the relay is in use (the VPN
     * service restarted by Android, always-on VPN, a boot start), from the config the app saved.
     * Off unless the user started the relay.
     */
    fun autoStart(ctx: Context) {
        try {
            val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            if (!prefs.getBoolean(PREF_ACTIVE, false)) return
            val config = prefs.getString(PREF_CONFIG, null)
            if (config.isNullOrBlank()) return
            Thread {
                try {
                    if (!running) start(ctx.applicationContext, config)?.let { Log.w(TAG, "auto start: $it") }
                } catch (t: Throwable) {
                    Log.w(TAG, "auto start", t)
                }
            }.apply { isDaemon = true; name = "raman-relay-autostart" }.start()
        } catch (t: Throwable) {
            Log.w(TAG, "auto start", t)
        }
    }
}
