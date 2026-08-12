package com.example.lembretes_app

import android.content.Context
import android.media.AudioManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import org.jitsi.meet.sdk.JitsiInitializer
import org.json.JSONObject

class MainActivity: FlutterActivity() {
    private val VOLUME_CHANNEL = "com.example.lembretes_app/volume"
    private val VIBRATION_CHANNEL = "com.example.lembretes_app/vibration"
    private val SECURE_CACHE_CHANNEL = "com.example.lembretes_app/secure_cache"
    private val JITSI_CHANNEL = "com.example.lembretes_app/jitsi"
    private val SECURE_CACHE_ALIAS = "lembrete_amigo_secure_cache_key"
    private val SECURE_CACHE_PREFS = "secure_cache_store"
    private val jitsiInitializationLock = Any()
    private val jitsiInitializationResults = mutableListOf<MethodChannel.Result>()

    @Volatile
    private var isJitsiInitialized = false

    @Volatile
    private var isJitsiInitializing = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOLUME_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getVolume") {
                val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                val currentVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                val volumePercentage = if (maxVolume > 0) (currentVolume.toFloat() / maxVolume.toFloat() * 100).toInt() else 0
                result.success(volumePercentage)
            } else if (call.method == "setSafeVolume") {
                val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                val safeVolume = (maxVolume * 0.75f).toInt().coerceAtLeast(1)
                audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, safeVolume, AudioManager.FLAG_SHOW_UI)
                val volumePercentage = if (maxVolume > 0) (safeVolume.toFloat() / maxVolume.toFloat() * 100).toInt() else 0
                result.success(volumePercentage)
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VIBRATION_CHANNEL).setMethodCallHandler { call, result ->
            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            if (call.method == "startVibration") {
                val pattern = longArrayOf(0, 700, 300)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator.vibrate(VibrationEffect.createWaveform(pattern, 0))
                } else {
                    @Suppress("DEPRECATION")
                    vibrator.vibrate(pattern, 0)
                }
                result.success(null)
            } else if (call.method == "stopVibration") {
                vibrator.cancel()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURE_CACHE_CHANNEL).setMethodCallHandler { call, result ->
            val key = call.argument<String>("key")
            if (key.isNullOrBlank()) {
                result.error("invalid_key", "Chave de cache invalida.", null)
                return@setMethodCallHandler
            }

            try {
                when (call.method) {
                    "read" -> result.success(readSecureCache(key))
                    "write" -> {
                        val value = call.argument<String>("value")
                        if (value == null) {
                            result.error("invalid_value", "Valor de cache invalido.", null)
                            return@setMethodCallHandler
                        }
                        writeSecureCache(key, value)
                        result.success(null)
                    }
                    "delete" -> {
                        deleteSecureCache(key)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("secure_cache_error", e.message, null)
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, JITSI_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "initialize") {
                initializeJitsi(result)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun initializeJitsi(result: MethodChannel.Result) {
        var shouldStart = false

        synchronized(jitsiInitializationLock) {
            if (isJitsiInitialized) {
                result.success(null)
                return
            }

            jitsiInitializationResults.add(result)
            if (!isJitsiInitializing) {
                isJitsiInitializing = true
                shouldStart = true
            }
        }

        if (!shouldStart) return

        Thread({
            val failure = try {
                JitsiInitializer().create(application)
                null
            } catch (error: Throwable) {
                error
            }

            runOnUiThread {
                val pendingResults: List<MethodChannel.Result>
                synchronized(jitsiInitializationLock) {
                    isJitsiInitialized = failure == null
                    isJitsiInitializing = false
                    pendingResults = jitsiInitializationResults.toList()
                    jitsiInitializationResults.clear()
                }

                pendingResults.forEach { pendingResult ->
                    if (failure == null) {
                        pendingResult.success(null)
                    } else {
                        pendingResult.error(
                            "jitsi_initialization_error",
                            failure.message ?: "Nao foi possivel preparar a videochamada.",
                            null,
                        )
                    }
                }
            }
        }, "JitsiInitializer").start()
    }

    private fun securePrefs() = getSharedPreferences(SECURE_CACHE_PREFS, Context.MODE_PRIVATE)

    private fun getOrCreateSecretKey(): SecretKey {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            throw UnsupportedOperationException("Android KeyStore AES requer Android 6 ou superior.")
        }

        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val existingKey = keyStore.getKey(SECURE_CACHE_ALIAS, null)
        if (existingKey is SecretKey) return existingKey

        val keyGenerator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            "AndroidKeyStore"
        )
        val keySpec = KeyGenParameterSpec.Builder(
            SECURE_CACHE_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setRandomizedEncryptionRequired(true)
            .build()
        keyGenerator.init(keySpec)
        return keyGenerator.generateKey()
    }

    private fun writeSecureCache(key: String, value: String) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateSecretKey())
        val encrypted = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        val payload = JSONObject()
            .put("iv", Base64.encodeToString(cipher.iv, Base64.NO_WRAP))
            .put("value", Base64.encodeToString(encrypted, Base64.NO_WRAP))
            .toString()
        securePrefs().edit().putString(key, payload).apply()
    }

    private fun readSecureCache(key: String): String? {
        val payload = securePrefs().getString(key, null) ?: return null
        return try {
            val json = JSONObject(payload)
            val iv = Base64.decode(json.getString("iv"), Base64.NO_WRAP)
            val encrypted = Base64.decode(json.getString("value"), Base64.NO_WRAP)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, getOrCreateSecretKey(), GCMParameterSpec(128, iv))
            String(cipher.doFinal(encrypted), Charsets.UTF_8)
        } catch (e: Exception) {
            deleteSecureCache(key)
            null
        }
    }

    private fun deleteSecureCache(key: String) {
        securePrefs().edit().remove(key).apply()
    }
}
