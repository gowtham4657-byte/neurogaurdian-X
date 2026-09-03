package com.neuroguardian.neuroguardian_app

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.neuroguardian.config"
    private val prefsName = "ngx_emergency_config"
    private val setupAction = "com.neuroguardian.neuroguardian_app.SET_EMERGENCY_CONFIG"

    override fun onCreate(savedInstanceState: Bundle?) {
        saveEmergencyConfig(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        saveEmergencyConfig(intent)
        super.onNewIntent(intent)
        setIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getEmergencyConfig" -> result.success(readEmergencyConfig())
                    else -> result.notImplemented()
                }
            }
    }

    private fun saveEmergencyConfig(intent: Intent?) {
        if (intent?.action != setupAction) return
        val prefs = getSharedPreferences(prefsName, MODE_PRIVATE)
        val editor = prefs.edit()
        putIfPresent(editor, intent, "backendUrl")
        putIfPresent(editor, intent, "backendToken")
        putIfPresent(editor, intent, "guardianPushTarget")
        editor.apply()
    }

    private fun putIfPresent(
        editor: android.content.SharedPreferences.Editor,
        intent: Intent,
        key: String
    ) {
        val value = intent.getStringExtra(key)?.trim()
        if (!value.isNullOrEmpty()) editor.putString(key, value)
    }

    private fun readEmergencyConfig(): Map<String, String> {
        val prefs = getSharedPreferences(prefsName, MODE_PRIVATE)
        return mapOf(
            "backendUrl" to (prefs.getString("backendUrl", "") ?: ""),
            "backendToken" to (prefs.getString("backendToken", "") ?: ""),
            "guardianPushTarget" to (prefs.getString("guardianPushTarget", "") ?: "")
        )
    }
}
