package com.example.lembretes_app

import android.content.Context
import android.media.AudioManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val VOLUME_CHANNEL = "com.example.lembretes_app/volume"
    private val VIBRATION_CHANNEL = "com.example.lembretes_app/vibration"

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
    }
}
