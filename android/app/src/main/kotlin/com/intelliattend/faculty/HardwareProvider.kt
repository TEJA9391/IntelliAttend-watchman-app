package com.intelliattend.faculty

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import android.os.Build
import android.provider.Settings
import android.util.DisplayMetrics
import android.view.WindowManager
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest
import com.scottyab.rootbeer.RootBeer
import kotlinx.coroutines.tasks.await
import java.net.Inet4Address
import java.net.NetworkInterface
import java.security.MessageDigest

class HardwareProvider(private val context: Context) {

    fun getDeviceId(): String {
        return Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID)
    }

    fun getDeviceMetadata(): Map<String, String> {
        return mapOf(
            "brand" to Build.BRAND,
            "model" to Build.MODEL,
            "manufacturer" to Build.MANUFACTURER,
            "androidVersion" to Build.VERSION.RELEASE,
            "sdkVersion" to Build.VERSION.SDK_INT.toString()
        )
    }

    fun getDeviceName(): String {
        return try {
            val globalName = Settings.Global.getString(context.contentResolver, Settings.Global.DEVICE_NAME)
            if (!globalName.isNullOrBlank()) return globalName
            val secureName = Settings.Secure.getString(context.contentResolver, "bluetooth_name")
            if (!secureName.isNullOrBlank()) return secureName
            "${Build.MANUFACTURER} ${Build.MODEL}"
        } catch (e: Exception) {
            "${Build.MANUFACTURER} ${Build.MODEL}"
        }
    }

    fun getCpuArchitecture(): String {
        return try {
            val abi = Build.SUPPORTED_ABIS.firstOrNull() ?: "unknown"
            abi
        } catch (e: Exception) {
            "unknown"
        }
    }

    fun getScreenResolution(): String {
        return try {
            val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val metrics = DisplayMetrics()
            @Suppress("DEPRECATION")
            wm.defaultDisplay.getRealMetrics(metrics)
            "${metrics.widthPixels}x${metrics.heightPixels}"
        } catch (e: Exception) {
            "unknown"
        }
    }

    fun getLocalIpAddress(): String {
        return try {
            val interfaces = NetworkInterface.getNetworkInterfaces()
            while (interfaces.hasMoreElements()) {
                val networkInterface = interfaces.nextElement()
                if (networkInterface.isLoopback || !networkInterface.isUp) continue
                val addresses = networkInterface.inetAddresses
                while (addresses.hasMoreElements()) {
                    val address = addresses.nextElement()
                    if (!address.isLoopbackAddress && address is Inet4Address) {
                        return address.hostAddress ?: "unknown"
                    }
                }
            }
            "unknown"
        } catch (e: Exception) {
            "unknown"
        }
    }

    fun getNetworkType(): String {
        return try {
            val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val network = cm.activeNetwork ?: return "unknown"
            val caps = cm.getNetworkCapabilities(network) ?: return "unknown"
            when {
                caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "Wi-Fi"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "Mobile"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "Ethernet"
                else -> "Other"
            }
        } catch (e: Exception) {
            "unknown"
        }
    }

    fun hasScreenLock(): Boolean {
        return try {
            val km = context.getSystemService(Context.KEYGUARD_SERVICE) as android.app.KeyguardManager
            km.isDeviceSecure
        } catch (e: Exception) {
            false
        }
    }

    fun isDeviceRooted(): Boolean {
        return RootBeer(context).isRooted
    }

    suspend fun getDeviceFingerprint(): String {
        return try {
            val metadata = getDeviceMetadata().values.joinToString("|")
            val deviceId = getDeviceId()
            val combined = metadata + "|" + deviceId
            MessageDigest.getInstance("SHA-256")
                .digest(combined.toByteArray())
                .joinToString("") { "%02x".format(it) }
        } catch (e: Exception) {
            "error_fingerprint_${e.message}"
        }
    }

    suspend fun getIntegrityToken(nonce: String): String {
        return try {
            val integrityManager = IntegrityManagerFactory.create(context)
            val request = IntegrityTokenRequest.builder()
                .setNonce(nonce)
                .build()
            integrityManager.requestIntegrityToken(request).await().token()
        } catch (e: Exception) {
            "error_integrity_${e.message}"
        }
    }

    @SuppressLint("MissingPermission")
    fun getFullDeviceInfo(): Map<String, Any> {
        val info = mutableMapOf<String, Any>()

        // ── General ──
        info["device_name"] = getDeviceName()
        info["manufacturer"] = Build.MANUFACTURER
        info["model"] = Build.MODEL
        info["brand"] = Build.BRAND
        info["device"] = Build.DEVICE
        info["product"] = Build.PRODUCT
        info["android_version"] = Build.VERSION.RELEASE
        info["sdk_version"] = Build.VERSION.SDK_INT.toString()
        info["security_patch"] = try { Build.VERSION.SECURITY_PATCH } catch (_: Exception) { "unknown" }
        info["build_number"] = Build.DISPLAY
        info["kernel_version"] = try { System.getProperty("os.version") ?: "unknown" } catch (_: Exception) { "unknown" }

        // ── Hardware ──
        info["cpu_architecture"] = Build.SUPPORTED_ABIS.firstOrNull() ?: "unknown"

        // RAM
        try {
            val am = context.getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
            val memInfo = android.app.ActivityManager.MemoryInfo()
            am.getMemoryInfo(memInfo)
            info["ram_total_mb"] = memInfo.totalMem / (1024 * 1024)
            info["ram_available_mb"] = memInfo.availMem / (1024 * 1024)
        } catch (_: Exception) {
            info["ram_total_mb"] = 0
            info["ram_available_mb"] = 0
        }

        // Storage
        try {
            val stat = android.os.StatFs(android.os.Environment.getDataDirectory().path)
            val totalBytes = stat.totalBytes
            val availBytes = stat.availableBytes
            info["storage_total_gb"] = String.format("%.1f", totalBytes / (1024.0 * 1024.0 * 1024.0))
            info["storage_available_gb"] = String.format("%.1f", availBytes / (1024.0 * 1024.0 * 1024.0))
        } catch (_: Exception) {
            info["storage_total_gb"] = "unknown"
            info["storage_available_gb"] = "unknown"
        }

        // Screen
        try {
            val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val metrics = android.util.DisplayMetrics()
            @Suppress("DEPRECATION")
            wm.defaultDisplay.getRealMetrics(metrics)
            info["screen_resolution"] = "${metrics.widthPixels}x${metrics.heightPixels}"
            info["screen_density"] = "${metrics.densityDpi} dpi"
            info["screen_refresh_rate"] = try {
                @Suppress("DEPRECATION")
                val refreshRate = wm.defaultDisplay.refreshRate
                "${String.format("%.0f", refreshRate)} Hz"
            } catch (_: Exception) { "unknown" }
        } catch (_: Exception) {
            info["screen_resolution"] = "unknown"
            info["screen_density"] = "unknown"
            info["screen_refresh_rate"] = "unknown"
        }

        // Battery
        try {
            val batteryIntent = context.registerReceiver(null, android.content.IntentFilter(android.content.Intent.ACTION_BATTERY_CHANGED))
            if (batteryIntent != null) {
                val level = batteryIntent.getIntExtra(android.os.BatteryManager.EXTRA_LEVEL, -1)
                val scale = batteryIntent.getIntExtra(android.os.BatteryManager.EXTRA_SCALE, -1)
                val pct = if (scale > 0) (level * 100) / scale else -1
                info["battery_percentage"] = pct

                val health = batteryIntent.getIntExtra(android.os.BatteryManager.EXTRA_HEALTH, -1)
                info["battery_health"] = when (health) {
                    android.os.BatteryManager.BATTERY_HEALTH_GOOD -> "Good"
                    android.os.BatteryManager.BATTERY_HEALTH_OVERHEAT -> "Overheat"
                    android.os.BatteryManager.BATTERY_HEALTH_DEAD -> "Dead"
                    android.os.BatteryManager.BATTERY_HEALTH_OVER_VOLTAGE -> "Over Voltage"
                    android.os.BatteryManager.BATTERY_HEALTH_COLD -> "Cold"
                    else -> "Unknown"
                }

                val status = batteryIntent.getIntExtra(android.os.BatteryManager.EXTRA_STATUS, -1)
                info["charging_status"] = when (status) {
                    android.os.BatteryManager.BATTERY_STATUS_CHARGING -> "Charging"
                    android.os.BatteryManager.BATTERY_STATUS_DISCHARGING -> "Discharging"
                    android.os.BatteryManager.BATTERY_STATUS_FULL -> "Full"
                    android.os.BatteryManager.BATTERY_STATUS_NOT_CHARGING -> "Not Charging"
                    else -> "Unknown"
                }

                val temperature = batteryIntent.getIntExtra(android.os.BatteryManager.EXTRA_TEMPERATURE, -1)
                info["battery_temperature"] = if (temperature > 0) "${temperature / 10.0}°C" else "unknown"
            }
        } catch (_: Exception) {
            info["battery_percentage"] = -1
            info["battery_health"] = "unknown"
            info["charging_status"] = "unknown"
            info["battery_temperature"] = "unknown"
        }

        // ── Network ──
        info["local_ip"] = getLocalIpAddress()
        info["network_type"] = getNetworkType()

        try {
            val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val wifiInfo = wifiManager.connectionInfo
            info["wifi_ssid"] = wifiInfo?.ssid?.replace("\"", "") ?: "Not connected"
            info["wifi_bssid"] = wifiInfo?.bssid ?: "unknown"
        } catch (_: Exception) {
            info["wifi_ssid"] = "unknown"
            info["wifi_bssid"] = "unknown"
        }

        try {
            val tm = context.getSystemService(Context.TELEPHONY_SERVICE) as android.telephony.TelephonyManager
            info["carrier_name"] = tm.networkOperatorName ?: "unknown"
            info["sim_operator"] = tm.simOperatorName ?: "unknown"
        } catch (_: Exception) {
            info["carrier_name"] = "unknown"
            info["sim_operator"] = "unknown"
        }

        // ── Security ──
        info["has_screen_lock"] = hasScreenLock()
        info["is_rooted"] = isDeviceRooted()

        try {
            val pm = context.packageManager
            info["developer_options"] = try {
                Settings.Global.getInt(context.contentResolver, Settings.Global.DEVELOPMENT_SETTINGS_ENABLED) == 1
            } catch (_: Exception) { false }
            info["usb_debugging"] = try {
                Settings.Global.getInt(context.contentResolver, "adb_enabled") == 1
            } catch (_: Exception) { false }
        } catch (_: Exception) {
            info["developer_options"] = false
            info["usb_debugging"] = false
        }

        try {
            val km = context.getSystemService(Context.KEYGUARD_SERVICE) as android.app.KeyguardManager
            info["has_screen_lock"] = km.isDeviceSecure
            info["fingerprint_enabled"] = try {
                val pm2 = context.packageManager
                pm2.hasSystemFeature(android.content.pm.PackageManager.FEATURE_FINGERPRINT)
            } catch (_: Exception) { false }
            info["face_unlock_enabled"] = try {
                val pm2 = context.packageManager
                pm2.hasSystemFeature("android.hardware.biometrics.face")
            } catch (_: Exception) { false }
        } catch (_: Exception) {
            info["fingerprint_enabled"] = false
            info["face_unlock_enabled"] = false
        }

        // ── Application ──
        try {
            val pm = context.packageManager
            val pkgInfo = pm.getPackageInfo(context.packageName, 0)
            info["app_version"] = pkgInfo.versionName ?: "unknown"
            info["app_version_code"] = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                pkgInfo.longVersionCode.toString()
            } else {
                @Suppress("DEPRECATION")
                pkgInfo.versionCode.toString()
            }
            info["install_time"] = pkgInfo.firstInstallTime
            info["update_time"] = pkgInfo.lastUpdateTime

            info["notification_permitted"] = try {
                val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
                nm.areNotificationsEnabled()
            } catch (_: Exception) { true }
        } catch (_: Exception) {
            info["app_version"] = "unknown"
            info["app_version_code"] = "unknown"
            info["install_time"] = 0L
            info["update_time"] = 0L
            info["notification_permitted"] = true
        }

        info["device_id"] = getDeviceId()

        return info
    }
}
