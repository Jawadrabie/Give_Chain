package com.givechain.app

import android.app.Application

/**
 * Applies the saved appearance before any Activity (and its splash) is created,
 * so the first cold start after a manual theme change matches that choice.
 * On first install there is no saved value → follow the device theme.
 */
class GiveChainApplication : Application() {
    override fun onCreate() {
        NativeTheme.applyFromPrefs(this)
        super.onCreate()
    }
}
