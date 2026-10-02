package com.example.yswords

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.InstallStatus
import com.google.android.play.core.install.model.UpdateAvailability
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Play decides eligibility for the signed package and the current tester.
 * GitHub version names cannot tell us whether that account can install a build. */
object PlayUpdateBridge {
    fun register(activity: Activity, engine: FlutterEngine) {
        val manager = AppUpdateManagerFactory.create(activity)
        MethodChannel(engine.dartExecutor.binaryMessenger, "yahweh/play_update")
            .setMethodCallHandler { call, result ->
                val installer = try {
                    if (Build.VERSION.SDK_INT >= 30)
                        activity.packageManager.getInstallSourceInfo(activity.packageName).installingPackageName
                    else {
                        @Suppress("DEPRECATION")
                        activity.packageManager.getInstallerPackageName(activity.packageName)
                    }
                } catch (_: Exception) { null }
                if (installer != "com.android.vending") {
                    result.success(null)
                } else when (call.method) {
                    "check" -> manager.appUpdateInfo.addOnSuccessListener { info ->
                        result.success(mapOf(
                            "available" to (info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE &&
                                info.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE)),
                            "code" to info.availableVersionCode(),
                            "downloaded" to (info.installStatus() == InstallStatus.DOWNLOADED),
                            "downloading" to (info.installStatus() == InstallStatus.DOWNLOADING ||
                                info.installStatus() == InstallStatus.PENDING),
                            "bytes" to info.bytesDownloaded(),
                            "total" to info.totalBytesToDownload()
                        ))
                    }.addOnFailureListener { result.error("play_check", "Google Play could not check updates.", null) }
                    "start" -> manager.appUpdateInfo.addOnSuccessListener { info ->
                        try {
                            // Fetch a fresh AppUpdateInfo for each tap; Play intents are single-use.
                            @Suppress("DEPRECATION")
                            val started = info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE &&
                                info.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE) &&
                                manager.startUpdateFlowForResult(info, AppUpdateType.FLEXIBLE, activity, 7312)
                            result.success(started)
                        } catch (_: Exception) {
                            result.error("play_start", "Google Play could not start the update.", null)
                        }
                    }.addOnFailureListener { result.error("play_start", "Google Play could not start the update.", null) }
                    "complete" -> manager.completeUpdate()
                        .addOnSuccessListener { result.success(true) }
                        .addOnFailureListener { result.error("play_complete", "Google Play could not install the update.", null) }
                    "store" -> {
                        try {
                            activity.startActivity(Intent(Intent.ACTION_VIEW,
                                Uri.parse("market://details?id=${activity.packageName}")).setPackage("com.android.vending"))
                            result.success(true)
                        } catch (_: Exception) {
                            result.error("play_store", "Google Play could not open.", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
