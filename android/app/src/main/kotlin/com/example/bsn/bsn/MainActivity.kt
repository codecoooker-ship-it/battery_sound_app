package com.example.bsn.bsn

import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.bsn.bsn/battery"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getBatteryInfo") {
                val intent = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
                val temp = intent?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0) ?: 0
                val voltage = intent?.getIntExtra(BatteryManager.EXTRA_VOLTAGE, 0) ?: 0
                val health = intent?.getIntExtra(BatteryManager.EXTRA_HEALTH, 0) ?: 0

                val info = mapOf(
                    "temp" to (temp / 10.0), // Celsius এ কনভার্ট করা হলো
                    "voltage" to voltage,    // mV এ ভোল্টেজ
                    "health" to health
                )
                result.success(info)
            } else {
                result.notImplemented()
            }
        }
    }
}