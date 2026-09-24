package com.example.my_print_shop

import android.content.pm.ApplicationInfo
import android.util.Log
import com.google.firebase.auth.FirebaseAuth
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val TESTING_CHANNEL = "com.example.my_print_shop/testing"
        private const val TAG = "MyPrintShop.MainActivity"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TESTING_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setAppVerificationDisabledForTesting" -> {
                        try {
                            val enable = call.argument<Boolean>("enable") ?: false
                            val applied = if (isDebuggable()) {
                                FirebaseAuth.getInstance().firebaseAuthSettings
                                    .setAppVerificationDisabledForTesting(enable)
                                Log.i(TAG, "App verification disabled for testing = $enable")
                                true
                            } else {
                                Log.w(TAG, "Ignoring test-mode request on non-debuggable build")
                                false
                            }
                            result.success(applied)
                        } catch (e: Exception) {
                            Log.e(TAG, "setAppVerificationDisabledForTesting failed", e)
                            result.error("TESTING_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isDebuggable(): Boolean =
        (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
}
