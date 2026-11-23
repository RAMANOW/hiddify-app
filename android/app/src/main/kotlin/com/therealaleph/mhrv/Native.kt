package com.therealaleph.mhrv

/**
 * JNI bindings of libmhrv_rs.so: mhrv-rs (https://github.com/therealaleph/MasterHttpRelayVPN-RUST,
 * MIT, by therealaleph; a Rust port of masterking32's MasterHttpRelayVPN). The library exports its
 * functions as Java_com_therealaleph_mhrv_Native_*, so this object keeps that package and name.
 *
 * Raman VPN loads it only when the user starts the Google Relay (com.hiddify.hiddify.RelayCore):
 * the first use of this object runs System.loadLibrary.
 */
object Native {
    init {
        System.loadLibrary("mhrv_rs")
    }

    /** Where the relay keeps its CA and cache. Call before anything else. */
    external fun setDataDir(path: String)

    /** Starts the proxy with a JSON config; returns a handle, 0 on failure (see drainLogs). */
    external fun startProxy(configJson: String): Long

    external fun stopProxy(handle: Long): Boolean

    /** Writes the MITM CA certificate (PEM) to destPath, creating the CA on first use. */
    external fun exportCa(destPath: String): Boolean

    external fun version(): String

    /** The log lines since the last call, '\n'-joined. */
    external fun drainLogs(): String

    /** {"ok":true,"latencyMs":123} or {"ok":false,"error":"..."}. Blocks. */
    external fun testSni(googleIp: String, sni: String): String

    /** Usage counters of a running proxy as JSON, or "". */
    external fun statsJson(handle: Long): String
}
