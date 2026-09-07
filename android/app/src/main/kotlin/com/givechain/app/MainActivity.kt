package com.givechain.app

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ObjectAnimator
import android.animation.PropertyValuesHolder
import android.animation.ValueAnimator
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.animation.AccelerateDecelerateInterpolator
import android.view.animation.DecelerateInterpolator
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.core.splashscreen.SplashScreenViewProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var keepSplashOnScreen = true

    override fun onCreate(savedInstanceState: Bundle?) {
        val splashScreen = installSplashScreen()
        splashScreen.setKeepOnScreenCondition { keepSplashOnScreen }
        splashScreen.setOnExitAnimationListener { splashView ->
            startPulseThenDismiss(splashView)
        }
        // Hand control to the exit animator quickly so pulsing can run longer.
        Handler(Looper.getMainLooper()).postDelayed({
            keepSplashOnScreen = false
        }, SPLASH_HANDOFF_MS)
        super.onCreate(savedInstanceState)
    }

    private fun startPulseThenDismiss(splashView: SplashScreenViewProvider) {
        val icon = splashView.iconView
        val pulse = ObjectAnimator.ofPropertyValuesHolder(
            icon,
            PropertyValuesHolder.ofFloat(View.SCALE_X, 1f, 1.16f),
            PropertyValuesHolder.ofFloat(View.SCALE_Y, 1f, 1.16f),
        ).apply {
            duration = PULSE_HALF_MS
            repeatCount = PULSE_REPEAT_COUNT
            repeatMode = ValueAnimator.REVERSE
            interpolator = AccelerateDecelerateInterpolator()
        }
        pulse.addListener(
            object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) {
                    icon.animate()
                        .scaleX(0.9f)
                        .scaleY(0.9f)
                        .alpha(0f)
                        .setDuration(FADE_OUT_MS)
                        .setInterpolator(DecelerateInterpolator())
                        .withEndAction { splashView.remove() }
                        .start()
                    splashView.view.animate()
                        .alpha(0f)
                        .setDuration(FADE_OUT_MS)
                        .setInterpolator(DecelerateInterpolator())
                        .start()
                }
            },
        )
        pulse.start()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            THEME_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setNightMode" -> {
                    val mode = call.argument<String>("mode")
                    NativeTheme.applyMode(mode)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    companion object {
        private const val THEME_CHANNEL = "givechain/theme"
        /** Short wait before Flutter releases the splash to our pulse animator. */
        private const val SPLASH_HANDOFF_MS = 350L
        /** One direction of the pulse (grow or shrink). */
        private const val PULSE_HALF_MS = 650L
        /**
         * Extra half-cycles after the first. With REVERSE this is about
         * (1 + repeat) * halfMs ≈ 4.5s of continuous pulsing.
         */
        private const val PULSE_REPEAT_COUNT = 6
        private const val FADE_OUT_MS = 400L
    }
}
