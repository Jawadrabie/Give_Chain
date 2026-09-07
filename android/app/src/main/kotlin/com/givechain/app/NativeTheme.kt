package com.givechain.app

import android.content.Context
import androidx.appcompat.app.AppCompatDelegate

/**
 * Keeps Android night mode (and therefore native splash resources) in sync
 * with the Flutter [ThemeController] preference stored in SharedPreferences.
 */
object NativeTheme {
    private const val PREFS_NAME = "FlutterSharedPreferences"
    private const val PREFS_KEY = "flutter.givechain_theme_mode"

    fun applyFromPrefs(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        applyMode(prefs.getString(PREFS_KEY, null))
    }

    fun applyMode(mode: String?) {
        val nightMode = when (mode) {
            "light" -> AppCompatDelegate.MODE_NIGHT_NO
            "dark" -> AppCompatDelegate.MODE_NIGHT_YES
            else -> AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM
        }
        AppCompatDelegate.setDefaultNightMode(nightMode)
    }
}
