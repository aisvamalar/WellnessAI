package com.wellnessai.wellness_ai

import io.flutter.embedding.android.FlutterActivity
import androidx.multidex.MultiDex
import android.content.Context

class MainActivity : FlutterActivity() {
    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        MultiDex.install(this)
    }
}
