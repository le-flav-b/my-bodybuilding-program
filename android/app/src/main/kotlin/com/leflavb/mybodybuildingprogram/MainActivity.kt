package com.leflavb.mybodybuildingprogram

import android.content.Context
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter app and the small "feedback" channel used by the workout
 * timers: a beep (ToneGenerator) and a vibration. No extra dependency.
 */
class MainActivity : FlutterActivity() {
    private var toneGenerator: ToneGenerator? = null
    private val handler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.leflavb.mybodybuildingprogram/feedback",
        ).setMethodCallHandler { call, result ->
            val durationMs = call.argument<Int>("durationMs") ?: 200
            when (call.method) {
                "beep" -> {
                    beep(durationMs)
                    result.success(null)
                }
                "vibrate" -> {
                    vibrate(durationMs.toLong())
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun beep(durationMs: Int) {
        try {
            val generator = toneGenerator
                ?: ToneGenerator(AudioManager.STREAM_MUSIC, 90).also { toneGenerator = it }
            generator.startTone(ToneGenerator.TONE_DTMF_A, durationMs)
            handler.postDelayed({ generator.stopTone() }, durationMs.toLong() + 50)
        } catch (e: RuntimeException) {
            // No audio output available: stay silent.
        }
    }

    private fun vibrate(durationMs: Long) {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        if (!vibrator.hasVibrator()) return
        vibrator.vibrate(
            VibrationEffect.createOneShot(durationMs, VibrationEffect.DEFAULT_AMPLITUDE),
        )
    }

    override fun onDestroy() {
        toneGenerator?.release()
        toneGenerator = null
        super.onDestroy()
    }
}
