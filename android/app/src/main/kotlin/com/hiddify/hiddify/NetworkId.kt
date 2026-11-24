package com.hiddify.hiddify

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import android.util.Log
import java.security.MessageDigest

/**
 * Raman VPN 1.9 per-network memory: a stable id and a label for the network under the VPN
 * (the VPN network itself is skipped). Read-only; it never changes a network or the VPN.
 *
 *  - Wi-Fi: the SSID when Android gives it. Since Android 8.1 that needs the location
 *    permission (and location on), which this app does not ask for, so it is usually hidden;
 *    then the id is a hash of the Wi-Fi's gateway and DNS servers (tells home from work in most
 *    cases) and the label is just "Wi-Fi".
 *  - Mobile data: the operator of the data SIM (MCC+MNC and its name, no permission needed).
 */
object NetworkId {
    private const val TAG = "RamanNetworkId"

    fun current(ctx: Context): Map<String, Any?> {
        try {
            val cm = ctx.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            @Suppress("DEPRECATION")
            val networks = cm.allNetworks
            var wifi: android.net.Network? = null
            var cell: android.net.Network? = null
            var other: android.net.Network? = null
            for (n in networks) {
                val caps = cm.getNetworkCapabilities(n) ?: continue
                if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) continue
                if (!caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) continue
                when {
                    caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> if (wifi == null) wifi = n
                    caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> if (cell == null) cell = n
                    else -> if (other == null) other = n
                }
            }
            wifi?.let { n -> return wifiId(ctx, cm, n) }
            cell?.let { return mobileId(ctx) }
            other?.let { n ->
                val lp = cm.getLinkProperties(n)
                return mapOf("kind" to "other", "key" to "other:" + hash(fingerprint(lp)), "label" to (lp?.interfaceName ?: "Network"), "hidden" to false)
            }
        } catch (t: Throwable) {
            Log.w(TAG, "network id", t)
        }
        return mapOf("kind" to "none", "key" to "", "label" to "", "hidden" to false)
    }

    private fun fingerprint(lp: android.net.LinkProperties?): String {
        if (lp == null) return ""
        val gw = lp.routes.filter { it.isDefaultRoute }.mapNotNull { it.gateway?.hostAddress }.sorted()
        val dns = lp.dnsServers.mapNotNull { it.hostAddress }.sorted()
        return "gw=" + gw.joinToString(",") + "|dns=" + dns.joinToString(",") + "|dom=" + (lp.domains ?: "")
    }

    private fun hash(s: String): String {
        val d = MessageDigest.getInstance("SHA-256").digest(s.toByteArray())
        return d.take(8).joinToString("") { "%02x".format(it) }
    }

    private fun cleanSsid(raw: String?): String? {
        if (raw == null) return null
        val s = raw.removePrefix("\"").removeSuffix("\"").trim()
        if (s.isEmpty() || s == WifiManager.UNKNOWN_SSID || s == "<unknown ssid>" || s == "0x") return null
        return s
    }

    private fun wifiId(ctx: Context, cm: ConnectivityManager, n: android.net.Network): Map<String, Any?> {
        var ssid: String? = null
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val info = cm.getNetworkCapabilities(n)?.transportInfo as? WifiInfo
                ssid = cleanSsid(info?.ssid)
            }
            if (ssid == null && ctx.checkSelfPermission(Manifest.permission.ACCESS_WIFI_STATE) == PackageManager.PERMISSION_GRANTED) {
                val wm = ctx.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                @Suppress("DEPRECATION")
                ssid = cleanSsid(wm.connectionInfo?.ssid)
            }
        } catch (t: Throwable) {
            Log.w(TAG, "ssid", t)
        }
        if (ssid != null) return mapOf("kind" to "wifi", "key" to "wifi:" + hash("ssid=$ssid"), "label" to ssid, "hidden" to false)
        val lp = cm.getLinkProperties(n)
        return mapOf("kind" to "wifi", "key" to "wifi:" + hash(fingerprint(lp)), "label" to "Wi-Fi", "hidden" to true)
    }

    private fun mobileId(ctx: Context): Map<String, Any?> {
        var tm = ctx.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
        try {
            val sub = SubscriptionManager.getDefaultDataSubscriptionId()
            if (tm != null && sub != SubscriptionManager.INVALID_SUBSCRIPTION_ID) tm = tm.createForSubscriptionId(sub)
        } catch (t: Throwable) {
            Log.w(TAG, "data sim", t)
        }
        val code = try { tm?.networkOperator ?: "" } catch (_: Throwable) { "" }
        val name = try {
            tm?.networkOperatorName?.takeIf { it.isNotBlank() } ?: tm?.simOperatorName?.takeIf { it.isNotBlank() }
        } catch (_: Throwable) { null }
        val key = if (code.isNotBlank()) "mobile:$code" else "mobile:" + (name ?: "unknown")
        return mapOf("kind" to "mobile", "key" to key, "label" to (name ?: "Mobile"), "hidden" to false)
    }
}
