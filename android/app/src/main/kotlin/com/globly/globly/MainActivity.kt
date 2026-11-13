package com.globly.globly

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Channel for comment/mention pushes; the id matches the manifest's FCM default.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel("comments", getString(R.string.channel_comments), NotificationManager.IMPORTANCE_HIGH)
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Self-update (lib/update/app_updater.dart): opens the system installer for a downloaded APK.
        // If installs from Globly aren't allowed yet, the installer asks for that first.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "globly/updater").setMethodCallHandler { call, result ->
            when (call.method) {
                "install" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("bad_args", "path is required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val uri = FileProvider.getUriForFile(this, "$packageName.updates", File(path))
                        val intent = Intent(Intent.ACTION_VIEW)
                            .setDataAndType(uri, "application/vnd.android.package-archive")
                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("install_failed", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Capture attestation (lib/widgets/capture_attestation.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "globly/attestation").setMethodCallHandler { call, result ->
            when (call.method) {
                "attest" -> {
                    val challenge = call.argument<ByteArray>("challenge")
                    if (challenge == null) {
                        result.error("bad_args", "challenge is required", null)
                        return@setMethodCallHandler
                    }
                    // Key generation can be slow.
                    Thread {
                        val outcome = runCatching { CaptureAttestation.attest(challenge) }
                        runOnUiThread {
                            outcome.fold(
                                { result.success(it) },
                                { result.error("attestation_failed", it.message, null) },
                            )
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }
}
