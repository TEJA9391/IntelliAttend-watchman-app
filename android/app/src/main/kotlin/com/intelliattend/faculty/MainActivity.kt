package com.intelliattend.faculty

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.provider.Settings
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.cancel
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.spec.ECGenParameterSpec
import java.util.Base64

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.intelliattend.faculty/hardware"
    private lateinit var hardwareProvider: HardwareProvider
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        hardwareProvider = HardwareProvider(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceFingerprint" -> {
                    scope.launch {
                        try {
                            val fingerprint = hardwareProvider.getDeviceFingerprint()
                            result.success(fingerprint)
                        } catch (e: Exception) {
                            result.error("HARDWARE_ERROR", "Fingerprint failed: ${e.message}", null)
                        }
                    }
                }
                "getIntegrityToken" -> {
                    val nonce = call.argument<String>("nonce")
                    if (nonce != null) {
                        scope.launch {
                            try {
                                val token = hardwareProvider.getIntegrityToken(nonce)
                                result.success(token)
                            } catch (e: Exception) {
                                result.error("INTEGRITY_ERROR", "Token failed: ${e.message}", null)
                            }
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Nonce is required", null)
                    }
                }
                "getDeviceMetadata" -> {
                    try {
                        result.success(hardwareProvider.getDeviceMetadata())
                    } catch (e: Exception) {
                        result.error("METADATA_ERROR", e.message, null)
                    }
                }
                "getDeviceId" -> {
                    try {
                        result.success(hardwareProvider.getDeviceId())
                    } catch (e: Exception) {
                        result.error("DEVICE_ID_ERROR", e.message, null)
                    }
                }
                "isDeviceRooted" -> {
                    try {
                        result.success(hardwareProvider.isDeviceRooted())
                    } catch (e: Exception) {
                        result.error("ROOT_ERROR", e.message, null)
                    }
                }
                "getDeviceName" -> {
                    try {
                        result.success(hardwareProvider.getDeviceName())
                    } catch (e: Exception) {
                        result.success("${Build.MANUFACTURER} ${Build.MODEL}")
                    }
                }
                "getCpuArchitecture" -> {
                    try {
                        result.success(hardwareProvider.getCpuArchitecture())
                    } catch (e: Exception) {
                        result.success("unknown")
                    }
                }
                "getScreenResolution" -> {
                    try {
                        result.success(hardwareProvider.getScreenResolution())
                    } catch (e: Exception) {
                        result.success("unknown")
                    }
                }
                "getLocalIpAddress" -> {
                    try {
                        result.success(hardwareProvider.getLocalIpAddress())
                    } catch (e: Exception) {
                        result.success("unknown")
                    }
                }
                "getNetworkType" -> {
                    try {
                        result.success(hardwareProvider.getNetworkType())
                    } catch (e: Exception) {
                        result.success("unknown")
                    }
                }
                "hasScreenLock" -> {
                    try {
                        result.success(hardwareProvider.hasScreenLock())
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "getFullDeviceInfo" -> {
                    try {
                        result.success(hardwareProvider.getFullDeviceInfo())
                    } catch (e: Exception) {
                        result.error("FULL_DEVICE_INFO_ERROR", e.message, null)
                    }
                }
                "isAutoTimeEnabled" -> {
                    try {
                        val autoTime = Settings.Global.getInt(
                            contentResolver,
                            Settings.Global.AUTO_TIME
                        ) == 1
                        result.success(autoTime)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "isAutoTimeZoneEnabled" -> {
                    try {
                        val autoTz = Settings.Global.getInt(
                            contentResolver,
                            Settings.Global.AUTO_TIME_ZONE
                        ) == 1
                        result.success(autoTz)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "getMonotonicTime" -> {
                    try {
                        result.success(SystemClock.elapsedRealtime())
                    } catch (e: Exception) {
                        result.success(0)
                    }
                }
                "openDateSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_DATE_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        applicationContext.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "generateKeyPair" -> {
                    scope.launch {
                        try {
                            val challenge = call.argument<String>("challenge")
                            val keyPairGenerator = KeyPairGenerator.getInstance(
                                KeyProperties.KEY_ALGORITHM_EC,
                                "AndroidKeyStore"
                            )
                            val spec = KeyGenParameterSpec.Builder(
                                "intelli_attend_key",
                                KeyProperties.PURPOSE_SIGN
                            )
                                .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
                                .setDigests(KeyProperties.DIGEST_SHA256)
                                .setIsStrongBoxBacked(true)
                                .apply {
                                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && challenge != null) {
                                        setAttestationChallenge(challenge.toByteArray())
                                    }
                                }
                                .build()
                            keyPairGenerator.initialize(spec)
                            keyPairGenerator.generateKeyPair()
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                }
                "signPayload" -> {
                    scope.launch {
                        try {
                            val data = call.argument<String>("data") ?: ""
                            val keyStore = KeyStore.getInstance("AndroidKeyStore")
                            keyStore.load(null)
                            val entry = keyStore.getEntry("intelli_attend_key", null) as? KeyStore.PrivateKeyEntry
                            if (entry == null) {
                                result.success(null)
                                return@launch
                            }
                            val signature = java.security.Signature.getInstance("SHA256withECDSA")
                            signature.initSign(entry.privateKey)
                            signature.update(data.toByteArray())
                            val sigBytes = signature.sign()
                            result.success(Base64.getEncoder().encodeToString(sigBytes))
                        } catch (e: Exception) {
                            result.success(null)
                        }
                    }
                }
                "getPublicKey" -> {
                    scope.launch {
                        try {
                            val keyStore = KeyStore.getInstance("AndroidKeyStore")
                            keyStore.load(null)
                            val entry = keyStore.getEntry("intelli_attend_key", null) as? KeyStore.PrivateKeyEntry
                            val publicKey = entry?.certificate?.publicKey
                            result.success(
                                publicKey?.let { Base64.getEncoder().encodeToString(it.encoded) }
                            )
                        } catch (e: Exception) {
                            result.success(null)
                        }
                    }
                }
                "isKeyPairGenerated" -> {
                    try {
                        val keyStore = KeyStore.getInstance("AndroidKeyStore")
                        keyStore.load(null)
                        result.success(keyStore.containsAlias("intelli_attend_key"))
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "deleteKeyPair" -> {
                    try {
                        val keyStore = KeyStore.getInstance("AndroidKeyStore")
                        keyStore.load(null)
                        keyStore.deleteEntry("intelli_attend_key")
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
