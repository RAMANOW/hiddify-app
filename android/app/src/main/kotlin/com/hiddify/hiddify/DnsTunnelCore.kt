package com.hiddify.hiddify

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.Inet6Address
import java.net.InetSocketAddress
import java.net.Socket

/**
 * Raman VPN's shutdown DNS tunnel ("DNS قطعی"): one of the open-source DNS-tunnel clients, shipped
 * as executables in the native library dir and run as a child process, listening as SOCKS5 on
 * 127.0.0.1 only:
 *  - soar: libsoarsocks.so (raman/dnstunnel/soarsocks; github.com/getlantern/soar, Apache-2.0)
 *  - cotten: libcottendns.so (the CottenDNS client by TaJirax, MIT, unchanged)
 *  - dnstt (1.8.2): libdnstt.so (dnstt-client by David Fifield, public domain / CC0, unchanged): a
 *    TCP forwarder to the server end, which hands each stream to its SOCKS5 proxy
 *  - slipstream (1.8.2): libslipstream.so (EndPositive/slipstream client, Apache-2.0): a TCP
 *    forwarder like dnstt; the server end must forward to a SOCKS5 proxy
 *  - masterdns (1.8.2): libmasterdns.so (the MasterDnsVPN client by Amin Mahmoudi, MIT, unchanged)
 * Each engine has its own loopback port (soar and cotten share 18096 as in 1.8); a test runs on the
 * port after it.
 * The Hiddify core reaches it through a local profile with one socks outbound
 * (lib/features/raman/dnstunnel). The engine's DNS queries leave directly: the VPN service always
 * excludes this app's package (and so its child processes, same uid) from the tunnel.
 *
 * A run spec (JSON from Dart) is {"engine":"soar"|"cotten","profile":{...link profile...},
 * "resolvers":[...],"useSystemDns":bool}; engine is also dnstt / slipstream / masterdns.
 */
object DnsTunnelCore {
    private const val TAG = "RamanDnsTunnel"
    const val PORT = 18096
    const val TEST_PORT = 18097

    /** engine -> (executable, main port); the test port is main + 1. */
    private val ENGINES = linkedMapOf(
        "soar" to ("libsoarsocks.so" to PORT),
        "cotten" to ("libcottendns.so" to PORT),
        "dnstt" to ("libdnstt.so" to 18098),
        "slipstream" to ("libslipstream.so" to 18100),
        "masterdns" to ("libmasterdns.so" to 18102),
    )

    fun engineOf(name: String?): String = if (name != null && ENGINES.containsKey(name)) name else "soar"

    fun portOf(engine: String, test: Boolean = false): Int = ENGINES.getValue(engineOf(engine)).second + if (test) 1 else 0

    private const val PREFS = "FlutterSharedPreferences"
    private const val PREF_ACTIVE = "flutter.raman-dns-active"
    private const val PREF_RUN = "flutter.raman-dns-run"

    class Run(val engine: String, val port: Int, val process: Process) {
        val log = ArrayDeque<String>()
        @Volatile var phase: String? = null
        @Volatile var percent: Int? = null
        @Volatile var exitCode: Int? = null
        @Volatile var resolvers: List<String> = emptyList()

        // Process.isAlive is API 26+; minSdk is 24
        fun alive(): Boolean = exitCode == null && try {
            process.exitValue()
            false
        } catch (_: IllegalThreadStateException) {
            true
        }

        @Synchronized
        fun add(line: String) {
            if (log.size >= 300) log.removeFirst()
            log.addLast(line)
        }

        @Synchronized
        fun lines(): List<String> = log.toList()
    }

    @Volatile
    private var main: Run? = null
    @Volatile
    private var testRun: Run? = null

    private val ansi = Regex("\u001B\\[[0-9;?]*[A-Za-z]|</?[a-z]+>")
    private val progress = Regex("WD_PROGRESS phase=(\\S+) percent=(\\d+)")
    private val hostRe = Regex("^[A-Za-z0-9.-]{3,253}$")
    private val keyRe = Regex("^[A-Za-z0-9+/=_-]{16,256}$")
    private val hexKeyRe = Regex("^[0-9A-Fa-f]{64}$")
    private val v4Re = Regex("^\\d{1,3}(\\.\\d{1,3}){3}(:\\d{1,5})?$")
    private val v6PortRe = Regex("^\\[[0-9A-Fa-f:.]+\\](:\\d{1,5})?$")
    private val v6Re = Regex("^[0-9A-Fa-f:.]*:[0-9A-Fa-f:.]*$")
    private val dohRe = Regex("^https://[A-Za-z0-9.\\-\\[\\]:]+(/[A-Za-z0-9._~%!$&'()*+,;=:@/?-]*)?$")
    private val hostPortRe = Regex("^[A-Za-z0-9.-]{1,253}(:\\d{1,5})?$")

    fun binary(ctx: Context, engine: String): File =
        File(ctx.applicationInfo.nativeLibraryDir, ENGINES.getValue(engineOf(engine)).first)

    fun available(ctx: Context): Map<String, Any?> {
        val out = LinkedHashMap<String, Any?>()
        for (e in ENGINES.keys) {
            val f = binary(ctx, e)
            out[e] = f.isFile && f.canExecute()
        }
        out["dir"] = ctx.applicationInfo.nativeLibraryDir
        return out
    }

    /** A UDP resolver as host:port (53 when none; IPv6 in brackets), or null when it is not one. */
    private fun udpAddr(r: String): String? = when {
        v4Re.matches(r) -> if (r.contains(':')) r else "$r:53"
        v6PortRe.matches(r) -> if (r.endsWith("]")) "$r:53" else r
        v6Re.matches(r) -> "[$r]:53"
        else -> null
    }

    /** The resolvers of the phone's own network (Wi-Fi / mobile operator), never the VPN's. */
    fun systemDns(ctx: Context): List<String> {
        val out = LinkedHashSet<String>()
        try {
            val cm = ctx.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            @Suppress("DEPRECATION")
            val networks = cm.allNetworks
            val ordered = networks.sortedBy { n ->
                // the active underlying network first
                val caps = cm.getNetworkCapabilities(n)
                if (caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true) 0 else 1
            }
            for (n in ordered) {
                val caps = cm.getNetworkCapabilities(n) ?: continue
                if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) continue
                if (!caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) continue
                val lp = cm.getLinkProperties(n) ?: continue
                for (a in lp.dnsServers) {
                    val h = a.hostAddress ?: continue
                    if (a.isLoopbackAddress || a.isAnyLocalAddress) continue
                    // drop an IPv6 scope suffix (fe80::1%wlan0); link-local v6 is of no use here
                    if (a is Inet6Address && a.isLinkLocalAddress) continue
                    out.add(h.substringBefore('%'))
                }
            }
        } catch (t: Throwable) {
            Log.w(TAG, "system dns", t)
        }
        return out.toList()
    }

    private fun mergedResolvers(ctx: Context, spec: JSONObject): List<String> {
        val out = LinkedHashSet<String>()
        if (spec.optBoolean("useSystemDns", true)) out.addAll(systemDns(ctx))
        val arr = spec.optJSONArray("resolvers") ?: JSONArray()
        for (i in 0 until arr.length()) {
            val r = arr.optString(i).trim()
            if (r.isNotEmpty() && r.length < 64 && !r.contains('"') && !r.contains('\n')) out.add(r)
        }
        return out.toList()
    }

    private fun slotDir(ctx: Context, slot: String): File =
        File(File(ctx.filesDir, "dnstunnel"), slot).apply { mkdirs() }

    private fun pidFile(ctx: Context, slot: String) = File(slotDir(ctx, slot), "pid")

    private fun killStale(ctx: Context, slot: String) {
        val f = pidFile(ctx, slot)
        val pid = runCatching { f.readText().trim().toInt() }.getOrNull() ?: return
        runCatching {
            val cmd = File("/proc/$pid/cmdline").readText()
            if (ENGINES.values.any { cmd.contains(it.first) }) {
                android.os.Process.killProcess(pid)
                Thread.sleep(300)
            }
        }
        f.delete()
    }

    private fun tomlString(s: String) = "\"" + s.replace("\\", "\\\\").replace("\"", "\\\"") + "\""

    /** Writes the engine's config into [dir]; returns the command line, or throws. */
    private fun prepare(ctx: Context, engine: String, profile: JSONObject, resolvers: List<String>, port: Int, dir: File): List<String> {
        val server = profile.optJSONObject("server") ?: throw IllegalArgumentException("no server")
        val domain = server.optString("domain").trim().trimEnd('.')
        if (!hostRe.matches(domain)) throw IllegalArgumentException("bad domain")
        val bin = binary(ctx, engine).absolutePath
        if (engine == "dnstt") return prepareDnstt(bin, profile, server, domain, resolvers, port)
        if (engine == "slipstream") {
            // one family only (the client cannot mix IPv4 and IPv6 resolvers); IPv4 first
            val udp = resolvers.mapNotNull { udpAddr(it) }
            val v4 = udp.filter { !it.startsWith("[") }
            val use = (v4.ifEmpty { udp }).distinct().take(16)
            if (use.isEmpty()) throw IllegalArgumentException("no resolvers")
            val cmd = mutableListOf(bin, "--tcp-listen-port", port.toString(), "--domain", domain)
            for (r in use) { cmd += "--resolver"; cmd += r }
            return cmd
        }
        if (engine == "masterdns") {
            val key = server.optString("encryption_key").trim()
            if (!keyRe.matches(key)) throw IllegalArgumentException("bad encryption_key")
            val method = server.optInt("encryption_method", 5).coerceIn(0, 5)
            if (resolvers.isEmpty()) throw IllegalArgumentException("no resolvers")
            // MasterDnsVPN's own client_config.toml keys; everything else keeps the client's defaults
            val toml = """
                PROTOCOL_TYPE = "SOCKS5"
                LISTEN_IP = "127.0.0.1"
                LISTEN_PORT = $port
                SOCKS5_AUTH = false
                DOMAINS = [${tomlString(domain)}]
                ENCRYPTION_KEY = ${tomlString(key)}
                DATA_ENCRYPTION_METHOD = $method
                LOCAL_DNS_ENABLED = false
                AUTO_SAVE_RANKED_RESOLVERS = false
                INTERACTIVE_STATS_ENABLED = false
                SAVE_MTU_SERVERS_TO_FILE = false
                LOG_LEVEL = "INFO"
            """.trimIndent() + "\n"
            File(dir, "masterdns.toml").writeText(toml)
            File(dir, "masterdns-resolvers.txt").writeText(resolvers.joinToString("\n") + "\n")
            return listOf(bin, "-config", File(dir, "masterdns.toml").absolutePath, "-resolvers", File(dir, "masterdns-resolvers.txt").absolutePath)
        }
        if (engine == "cotten") {
            val key = server.optString("encryption_key").trim()
            if (!keyRe.matches(key)) throw IllegalArgumentException("bad encryption_key")
            val method = server.optInt("encryption_method", 5).coerceIn(0, 5)
            if (resolvers.isEmpty()) throw IllegalArgumentException("no resolvers")
            val logs = File(dir, "logs")
            logs.deleteRecursively()
            logs.mkdirs()
            // the shape of CottenDNS's own probe (probe/http.go) with the client's default
            // duplication and recovery; everything not set here keeps the client's defaults
            val toml = """
                PROTOCOL_TYPE = "SOCKS5"
                LISTEN_IP = "127.0.0.1"
                LISTEN_PORT = $port
                SOCKS5_AUTH = false
                DOMAINS = [${tomlString(domain)}]
                ENCRYPTION_KEY = ${tomlString(key)}
                DATA_ENCRYPTION_METHOD = $method
                LEGACY_SESSION_ID = false
                TUNNEL_MODE = "legacy"
                TERMINAL_UI = "plain"
                STARTUP_MODE = "resolvers"
                RESOLVER_TRANSPORT = "auto"
                QUERY_TYPES = ["TXT"]
                MIN_UPLOAD_MTU = 80
                MAX_UPLOAD_MTU = 142
                MIN_DOWNLOAD_MTU = 16
                MAX_DOWNLOAD_MTU = 1500
                FAST_CONNECT = true
                LOCAL_DNS_ENABLED = false
                LOG_LEVEL = "INFO"
                LOG_TO_FILE = false
                LOG_DIR = ${tomlString(logs.absolutePath)}
            """.trimIndent() + "\n"
            File(dir, "client.toml").writeText(toml)
            File(dir, "resolvers.txt").writeText(resolvers.joinToString("\n") + "\n")
            return listOf(bin, "-config", File(dir, "client.toml").absolutePath, "-resolvers", File(dir, "resolvers.txt").absolutePath)
        }
        val key = server.optString("public_key").trim()
        if (!keyRe.matches(key)) throw IllegalArgumentException("bad public_key")
        val p = JSONObject(profile.toString())
        p.put("resolvers", JSONArray(resolvers))
        val settings = p.optJSONObject("soarSettings")
        if (resolvers.isEmpty() && settings?.optBoolean("discovery", false) != true) throw IllegalArgumentException("no resolvers")
        File(dir, "soar.json").writeText(p.toString())
        return listOf(bin, "-config", File(dir, "soar.json").absolutePath, "-listen", "127.0.0.1:$port")
    }

    /**
     * dnstt-client [-doh URL | -dot HOST:PORT | -udp ADDR] -pubkey HEX DOMAIN 127.0.0.1:PORT. The
     * config's own resolver (a DoH URL, tls://host[:853], or an IP[:port]) when it has one, else the
     * first usable resolver of the list (phone's DNS first) over plain UDP; dnstt takes one only.
     */
    private fun prepareDnstt(bin: String, profile: JSONObject, server: JSONObject, domain: String, resolvers: List<String>, port: Int): List<String> {
        val key = server.optString("public_key").trim()
        if (!hexKeyRe.matches(key)) throw IllegalArgumentException("bad public_key (64 hex digits)")
        val own = profile.optString("resolver").trim()
        val transport: List<String> = when {
            own.startsWith("https://") -> {
                if (!dohRe.matches(own)) throw IllegalArgumentException("bad DoH URL")
                listOf("-doh", own)
            }
            own.startsWith("tls://") -> {
                val hp = own.removePrefix("tls://").trimEnd('/')
                if (!hostPortRe.matches(hp)) throw IllegalArgumentException("bad DoT address")
                listOf("-dot", if (hp.contains(':')) hp else "$hp:853")
            }
            own.isNotEmpty() -> listOf("-udp", udpAddr(own.removePrefix("udp://")) ?: throw IllegalArgumentException("bad resolver"))
            else -> listOf("-udp", resolvers.firstNotNullOfOrNull { udpAddr(it) } ?: throw IllegalArgumentException("no resolvers"))
        }
        return listOf(bin) + transport + listOf("-pubkey", key.lowercase(), domain, "127.0.0.1:$port")
    }

    private fun spawn(ctx: Context, spec: JSONObject, test: Boolean, slot: String): Run {
        val engine = engineOf(spec.optString("engine"))
        val port = portOf(engine, test)
        val profile = spec.optJSONObject("profile") ?: throw IllegalArgumentException("no profile")
        val resolvers = mergedResolvers(ctx, spec)
        val dir = slotDir(ctx, slot)
        killStale(ctx, slot)
        if (portOpen(port, 200)) throw IllegalStateException("port $port busy")
        val cmd = prepare(ctx, engine, profile, resolvers, port, dir)
        val pb = ProcessBuilder(cmd).directory(dir).redirectErrorStream(true)
        pb.environment()["HOME"] = dir.absolutePath
        pb.environment()["TMPDIR"] = ctx.cacheDir.absolutePath
        val process = pb.start()
        runCatching { process.outputStream.close() }
        val run = Run(engine, port, process)
        run.resolvers = if (engine == "dnstt") listOf(cmd[2]) else resolvers
        runCatching {
            val f = process.javaClass.getDeclaredField("pid")
            f.isAccessible = true
            pidFile(ctx, slot).writeText(f.getInt(process).toString())
        }
        Thread {
            try {
                process.inputStream.bufferedReader().forEachLine { raw ->
                    val line = raw.replace(ansi, "").trim()
                    if (line.isEmpty()) return@forEachLine
                    progress.find(line)?.let {
                        run.phase = it.groupValues[1]
                        run.percent = it.groupValues[2].toIntOrNull()
                    }
                    if (line.startsWith("RAMAN_READY")) {
                        run.phase = "listening"
                    }
                    run.add(line)
                }
            } catch (_: Throwable) {
            }
            run.exitCode = runCatching { process.waitFor() }.getOrDefault(-1)
            run.add("engine exited (${run.exitCode})")
            Log.i(TAG, "$engine on $port exited ${run.exitCode}")
        }.apply { isDaemon = true; name = "raman-dns-$slot" }.start()
        return run
    }

    /** Waits until [run] listens; null when it does, an error otherwise. */
    private fun waitListening(run: Run, timeoutMs: Long): String? {
        val deadline = System.currentTimeMillis() + timeoutMs
        while (System.currentTimeMillis() < deadline) {
            if (!run.alive()) return "exited: " + lastError(run)
            if (portOpen(run.port, 200)) return null
            Thread.sleep(250)
        }
        return "timeout: " + lastError(run)
    }

    private fun lastError(run: Run): String {
        val lines = run.lines()
        return lines.lastOrNull {
            it.contains("RAMAN_ERROR") || it.contains("ERROR") || it.contains("failed") || it.contains("Rejected")
        } ?: lines.lastOrNull() ?: ""
    }

    private fun kill(run: Run?) {
        if (run == null) return
        runCatching { run.process.destroy() }
        for (i in 0 until 15) {
            if (!run.alive()) return
            Thread.sleep(100)
        }
    }

    /** Starts the tunnel on [PORT] with [specJson]; null when it listens, the error otherwise. */
    fun start(ctx: Context, specJson: String, timeoutMs: Long = 150_000): String? {
        val spawned: Any = synchronized(this) {
            kill(main)
            main = null
            try {
                spawn(ctx, JSONObject(specJson), false, "main").also { main = it }
            } catch (t: Throwable) {
                Log.w(TAG, "start", t)
                t.message ?: t.javaClass.simpleName
            }
        }
        val run = spawned as? Run ?: return spawned as String
        val err = waitListening(run, timeoutMs)
        if (err != null) {
            synchronized(this) { if (main === run) { kill(run); main = null } }
        }
        return err
    }

    fun stop() {
        val r = synchronized(this) { main.also { main = null } }
        kill(r)
    }

    fun status(): Map<String, Any?> {
        val r = main
        return mapOf(
            "running" to (r?.alive() == true),
            "listening" to (r?.alive() == true && portOpen(r.port, 150)),
            "engine" to r?.engine,
            "port" to r?.port,
            "phase" to r?.phase,
            "percent" to r?.percent,
            "exitCode" to r?.exitCode,
            "resolvers" to (r?.resolvers ?: emptyList<String>()),
        )
    }

    fun logs(): List<String> = (main ?: testRun)?.lines() ?: emptyList()

    /**
     * A short real connection: starts the engine on [TEST_PORT], waits for it, then fetches
     * http://www.gstatic.com/generate_204 through its SOCKS5 port. {ok, ms, error, log}.
     */
    fun test(ctx: Context, specJson: String, timeoutMs: Long = 100_000): String {
        val started = System.currentTimeMillis()
        val out = JSONObject()
        val spawned: Any = synchronized(this) {
            kill(testRun)
            testRun = null
            try {
                spawn(ctx, JSONObject(specJson), true, "test").also { testRun = it }
            } catch (t: Throwable) {
                t.message ?: t.javaClass.simpleName
            }
        }
        val run = spawned as? Run ?: return out.put("ok", false).put("error", spawned as String).toString()
        try {
            val err = waitListening(run, timeoutMs)
            if (err != null) return out.put("ok", false).put("error", err).toString()
            val left = (timeoutMs - (System.currentTimeMillis() - started)).coerceAtLeast(15_000)
            // dnstt / slipstream servers may want a SOCKS5 login (from the link)
            val socks = JSONObject(specJson).optJSONObject("profile")?.optJSONObject("socks")
            val status = socksHttp(run.port, "www.gstatic.com", 80, "/generate_204", left.toInt(),
                socks?.optString("user").orEmpty(), socks?.optString("password").orEmpty())
            val ms = System.currentTimeMillis() - started
            return if (status in 200..399) {
                out.put("ok", true).put("ms", ms).put("status", status).toString()
            } else {
                out.put("ok", false).put("ms", ms).put("error", "HTTP $status").toString()
            }
        } catch (t: Throwable) {
            return out.put("ok", false).put("error", (t.message ?: t.javaClass.simpleName) + " | " + lastError(run)).toString()
        } finally {
            synchronized(this) { if (testRun === run) testRun = null }
            kill(run)
        }
    }

    fun cancelTest() {
        val r = synchronized(this) { testRun.also { testRun = null } }
        kill(r)
    }

    /** SOCKS5 CONNECT (host name sent as is) and a plain HTTP GET; returns the status code. */
    private fun socksHttp(port: Int, host: String, dport: Int, path: String, timeoutMs: Int, user: String = "", pass: String = ""): Int {
        Socket().use { s ->
            s.connect(InetSocketAddress("127.0.0.1", port), 3000)
            s.soTimeout = timeoutMs
            val o = s.getOutputStream()
            val i = s.getInputStream()
            val login = user.isNotEmpty()
            o.write(if (login) byteArrayOf(5, 2, 0, 2) else byteArrayOf(5, 1, 0)); o.flush()
            val g = ByteArray(2)
            readFully(i, g)
            if (g[0].toInt() != 5) throw IllegalStateException("not a SOCKS5 answer")
            if (g[1].toInt() == 2 && login) {
                val u = user.toByteArray().take(255).toByteArray()
                val p = pass.toByteArray().take(255).toByteArray()
                o.write(byteArrayOf(1, u.size.toByte()) + u + byteArrayOf(p.size.toByte()) + p); o.flush()
                val a = ByteArray(2)
                readFully(i, a)
                if (a[1].toInt() != 0) throw IllegalStateException("socks login refused")
            } else if (g[1].toInt() != 0) {
                throw IllegalStateException("socks auth refused")
            }
            val hb = host.toByteArray()
            val req = byteArrayOf(5, 1, 0, 3, hb.size.toByte()) + hb + byteArrayOf((dport shr 8).toByte(), (dport and 0xff).toByte())
            o.write(req); o.flush()
            val head = ByteArray(4)
            readFully(i, head)
            if (head[1].toInt() != 0) throw IllegalStateException("socks connect failed (${head[1]})")
            val skip = when (head[3].toInt()) { 1 -> 6; 4 -> 18; 3 -> i.read() + 2; else -> 6 }
            readFully(i, ByteArray(skip))
            o.write("GET $path HTTP/1.1\r\nHost: $host\r\nUser-Agent: Mozilla/5.0\r\nConnection: close\r\n\r\n".toByteArray())
            o.flush()
            val line = StringBuilder()
            while (true) {
                val c = i.read()
                if (c < 0 || c == '\n'.code) break
                line.append(c.toChar())
                if (line.length > 200) break
            }
            val parts = line.toString().trim().split(' ')
            return parts.getOrNull(1)?.toIntOrNull() ?: throw IllegalStateException("no HTTP answer")
        }
    }

    private fun readFully(i: java.io.InputStream, b: ByteArray) {
        var n = 0
        while (n < b.size) {
            val r = i.read(b, n, b.size - n)
            if (r < 0) throw java.io.EOFException("closed")
            n += r
        }
    }

    fun portOpen(port: Int, timeoutMs: Int): Boolean = try {
        Socket().use { it.connect(InetSocketAddress("127.0.0.1", port), timeoutMs); true }
    } catch (_: Exception) {
        false
    }

    /** Brings the tunnel back when the process starts again while it is in use. */
    fun autoStart(ctx: Context) {
        try {
            val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            if (!prefs.getBoolean(PREF_ACTIVE, false)) return
            val spec = prefs.getString(PREF_RUN, null)
            if (spec.isNullOrBlank()) return
            Thread {
                try {
                    if (main?.alive() != true) start(ctx.applicationContext, spec)?.let { Log.w(TAG, "auto start: $it") }
                } catch (t: Throwable) {
                    Log.w(TAG, "auto start", t)
                }
            }.apply { isDaemon = true; name = "raman-dns-autostart" }.start()
        } catch (t: Throwable) {
            Log.w(TAG, "auto start", t)
        }
    }
}
