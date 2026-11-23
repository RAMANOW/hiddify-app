package com.hiddify.hiddify

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.Settings
import android.security.KeyChain
import android.util.Base64
import com.therealaleph.mhrv.Native
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.KeyStore
import java.security.MessageDigest
import java.util.concurrent.Executors

/**
 * The Google Relay tab's platform side (channel com.ramanow.ramanvpn/relay): start and stop
 * [RelayCore], its logs and usage, the SNI test, and the per-install MITM CA (export to
 * Downloads, the system install screen, and whether it is installed). The CA install steps follow
 * mhrv-rs's own Android app (CaInstall.kt, MIT).
 */
class RelayHandler : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var context: Context? = null
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    companion object {
        const val channelName = "com.ramanow.ramanvpn/relay"
        private const val CA_NAME = "RamanVPN-relay-ca.crt"
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
                    { result.error("relay", it.message ?: it.javaClass.simpleName, null) },
                )
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val ctx = context ?: return result.error("no_context", "not attached", null)
        when (call.method) {
            "available" -> background(result) {
                val err = RelayCore.load(ctx)
                mapOf("ok" to (err == null), "error" to err, "version" to RelayCore.version(ctx))
            }
            "start" -> {
                val config = call.argument<String>("config") ?: return result.error("args", "config", null)
                background(result) { RelayCore.start(ctx, config) }
            }
            "stop" -> background(result) { RelayCore.stop(); true }
            "status" -> result.success(
                mapOf(
                    "running" to RelayCore.running,
                    "httpPort" to RelayCore.HTTP_PORT,
                    "socksPort" to RelayCore.SOCKS_PORT,
                ),
            )
            "stats" -> background(result) { RelayCore.stats() }
            "logs" -> background(result) { RelayCore.logs() }
            "testSni" -> {
                val ip = call.argument<String>("ip") ?: ""
                val sni = call.argument<String>("sni") ?: ""
                background(result) { RelayCore.testSni(ctx, ip, sni) }
            }
            "caExport" -> background(result) { exportCa(ctx) }
            "caInstalled" -> background(result) { caFingerprint(ctx)?.let { isInstalled(it) } ?: false }
            "caInstall" -> {
                // Android 10 and older: the system installer takes the certificate directly.
                // Android 11+ only installs CAs from Settings (the file saved in Downloads).
                try {
                    val der = caDer(ctx)
                    if (der != null && Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
                        val intent = KeyChain.createInstallIntent()
                            .putExtra(KeyChain.EXTRA_CERTIFICATE, der)
                            .putExtra(KeyChain.EXTRA_NAME, "Raman VPN relay")
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        ctx.startActivity(intent)
                        result.success("installer")
                    } else {
                        openSecuritySettings(ctx)
                        result.success("settings")
                    }
                } catch (e: Exception) {
                    result.success(if (openSecuritySettings(ctx)) "settings" else null)
                }
            }
            "openSettings" -> result.success(openSecuritySettings(ctx))
            else -> result.notImplemented()
        }
    }

    private fun caFile(ctx: Context) = File(RelayCore.dataDir(ctx), "export-ca.crt")

    /** Exports the CA (made on first use, per install) and saves a copy in Downloads. */
    private fun exportCa(ctx: Context): Map<String, Any?> {
        RelayCore.load(ctx)?.let { throw IllegalStateException(it) }
        val file = caFile(ctx)
        if (!Native.exportCa(file.absolutePath) || file.length() == 0L) throw IllegalStateException("export failed")
        val der = pemToDer(file.readBytes()) ?: throw IllegalStateException("bad certificate")
        val saved = saveToDownloads(ctx, derToPem(der))
        return mapOf(
            "path" to saved,
            "fingerprint" to sha256(der).joinToString(":") { "%02X".format(it) },
            "installed" to isInstalled(sha256(der)),
        )
    }

    private fun caDer(ctx: Context): ByteArray? {
        val file = caFile(ctx)
        if (!file.exists()) return null
        return pemToDer(file.readBytes())
    }

    private fun caFingerprint(ctx: Context): ByteArray? = caDer(ctx)?.let { sha256(it) }

    private fun saveToDownloads(ctx: Context, pem: ByteArray): String? = try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = ctx.contentResolver
            runCatching {
                resolver.delete(
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                    "${MediaStore.MediaColumns.DISPLAY_NAME}=?",
                    arrayOf(CA_NAME),
                )
            }
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, CA_NAME)
                put(MediaStore.MediaColumns.MIME_TYPE, "application/x-x509-ca-cert")
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            }
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            if (uri == null) null else {
                resolver.openOutputStream(uri)?.use { it.write(pem) }
                "Download/$CA_NAME"
            }
        } else {
            val dir = ctx.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
            if (dir == null) null else {
                dir.mkdirs()
                val f = File(dir, CA_NAME)
                f.writeBytes(pem)
                f.absolutePath
            }
        }
    } catch (_: Throwable) {
        null
    }

    private fun openSecuritySettings(ctx: Context): Boolean {
        for (action in listOf(Settings.ACTION_SECURITY_SETTINGS, Settings.ACTION_SETTINGS)) {
            try {
                ctx.startActivity(Intent(action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return true
            } catch (_: Exception) {
            }
        }
        return false
    }

    /** Whether a CA with this SHA-256 is in AndroidCAStore (system + user CAs). */
    private fun isInstalled(fingerprint: ByteArray): Boolean = try {
        val ks = KeyStore.getInstance("AndroidCAStore")
        ks.load(null)
        val aliases = ks.aliases()
        var found = false
        while (aliases.hasMoreElements() && !found) {
            val cert = ks.getCertificate(aliases.nextElement()) ?: continue
            found = runCatching { sha256(cert.encoded).contentEquals(fingerprint) }.getOrDefault(false)
        }
        found
    } catch (_: Throwable) {
        false
    }

    private fun sha256(b: ByteArray): ByteArray = MessageDigest.getInstance("SHA-256").digest(b)

    private fun pemToDer(raw: ByteArray): ByteArray? {
        val text = String(raw, Charsets.US_ASCII)
        val begin = text.indexOf("-----BEGIN CERTIFICATE-----")
        val end = text.indexOf("-----END CERTIFICATE-----")
        if (begin < 0 || end < 0) return null
        val body = text.substring(begin + "-----BEGIN CERTIFICATE-----".length, end).replace(Regex("\\s"), "")
        return runCatching { Base64.decode(body, Base64.DEFAULT) }.getOrNull()
    }

    private fun derToPem(der: ByteArray): ByteArray {
        val b64 = Base64.encodeToString(der, Base64.NO_WRAP).chunked(64).joinToString("\n")
        return "-----BEGIN CERTIFICATE-----\n$b64\n-----END CERTIFICATE-----\n".toByteArray(Charsets.US_ASCII)
    }
}
