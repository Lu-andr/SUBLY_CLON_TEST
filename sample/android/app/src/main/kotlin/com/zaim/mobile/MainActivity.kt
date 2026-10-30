package com.zaim.mobile

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.telephony.TelephonyManager
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import com.google.android.gms.ads.identifier.AdvertisingIdClient
import com.google.firebase.analytics.FirebaseAnalytics
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.zaim.mobile/attribution"
        private const val NOTIFICATION_CHANNEL = "com.zaim.mobile/notifications"
        private const val VERIFICATION_CHANNEL_ID = "subly_verification"
        private const val VERIFICATION_NOTIFICATION_ID = 2545
        private const val PREFS = "subly_attribution_cache"
        private const val KEY_REFERRER_READ = "referrer_read"
        private const val KEY_UTM_SOURCE = "utm_source"
        private const val KEY_INSTALL_SOURCE = "install_source"
        private const val KEY_GAID = "gaid"
        private const val KEY_APP_INSTANCE_ID = "app_instance_id"
        private const val KEY_MANUAL_COUNTRY = "manual_country"
    }

    private val worker = Executors.newSingleThreadExecutor()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Warm asynchronous identifiers immediately. Offer clicks never wait
        // for this work and read only values already persisted below.
        warmGaid()
        warmFirebaseAppInstanceId()
        readInstallReferrerOnce()
        ensureVerificationChannel()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getCachedAttribution" -> result.success(cachedAttribution())
                    "getContentCountry" -> result.success(contentCountry())
                    "setManualCountry" -> {
                        val country = call.argument<String>("country")
                            ?.trim()?.uppercase(Locale.US).orEmpty()
                        if (country.length == 2) {
                            prefs().edit().putString(KEY_MANUAL_COUNTRY, country).apply()
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "showVerificationCode" -> {
                        val code = call.argument<String>("code").orEmpty()
                        result.success(code.isNotBlank() && showVerificationCode(code))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        worker.shutdown()
        super.onDestroy()
    }

    private fun prefs() = getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun ensureVerificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            VERIFICATION_CHANNEL_ID,
            "Коды подтверждения",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Коды подтверждения заявки Sumly"
            enableVibration(true)
        }
        manager.createNotificationChannel(channel)
    }

    private fun showVerificationCode(code: String): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) return false

        return try {
            ensureVerificationChannel()
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                ?: Intent(this, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                this,
                0,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, VERIFICATION_CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(this)
            }
                .setSmallIcon(resources.getIdentifier("ic_notification", "drawable", packageName))
                .setContentTitle("Sumly · код подтверждения")
                .setContentText("Ваш код: $code")
                .setContentIntent(pendingIntent)
                .setAutoCancel(true)
                .setCategory(Notification.CATEGORY_MESSAGE)
                .setPriority(Notification.PRIORITY_HIGH)
                .setDefaults(Notification.DEFAULT_SOUND or Notification.DEFAULT_VIBRATE)
                .build()
            getSystemService(NotificationManager::class.java)
                .notify(VERIFICATION_NOTIFICATION_ID, notification)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun cachedAttribution(): Map<String, String> {
        val cache = prefs()
        return buildMap {
            cache.getString(KEY_UTM_SOURCE, null)?.takeIf { it.isNotBlank() }
                ?.let { put("utmSource", it) }
            cache.getString(KEY_GAID, null)?.takeIf { it.isNotBlank() }
                ?.let { put("gaid", it) }
            cache.getString(KEY_INSTALL_SOURCE, null)?.takeIf { it.isNotBlank() }
                ?.let { put("installSource", it) }
            cache.getString(KEY_APP_INSTANCE_ID, null)?.takeIf { it.isNotBlank() }
                ?.let { put("appInstanceId", it) }
        }
    }

    private fun warmGaid() {
        worker.execute {
            try {
                val info = AdvertisingIdClient.getAdvertisingIdInfo(applicationContext)
                if (!info.isLimitAdTrackingEnabled && !info.id.isNullOrBlank()) {
                    prefs().edit().putString(KEY_GAID, info.id).apply()
                }
            } catch (_: Exception) {
                // Missing/limited GAID is intentionally omitted from the click.
            }
        }
    }

    private fun warmFirebaseAppInstanceId() {
        try {
            FirebaseAnalytics.getInstance(this).appInstanceId
                .addOnSuccessListener { id ->
                    if (!id.isNullOrBlank()) {
                        prefs().edit().putString(KEY_APP_INSTANCE_ID, id).apply()
                    }
                }
        } catch (_: Exception) {
            // Firebase may be intentionally unconfigured in a reusable sample.
        }
    }

    private fun readInstallReferrerOnce() {
        if (prefs().getBoolean(KEY_REFERRER_READ, false)) return
        val client = InstallReferrerClient.newBuilder(this).build()
        client.startConnection(object : InstallReferrerStateListener {
            override fun onInstallReferrerSetupFinished(responseCode: Int) {
                if (responseCode != InstallReferrerClient.InstallReferrerResponse.OK) {
                    client.endConnection()
                    return
                }
                try {
                    val raw = client.installReferrer.installReferrer.orEmpty()
                    val query = Uri.parse("https://subly.local/?$raw")
                    val utmSource = query.getQueryParameter("utm_source").orEmpty()
                    val medium = query.getQueryParameter("utm_medium").orEmpty()
                    val source = when {
                        raw.isBlank() -> "organic"
                        medium.equals("organic", ignoreCase = true) -> "organic"
                        utmSource.equals("organic", ignoreCase = true) -> "organic"
                        else -> "ads"
                    }
                    prefs().edit()
                        .putString(KEY_UTM_SOURCE, utmSource)
                        .putString(KEY_INSTALL_SOURCE, source)
                        .putBoolean(KEY_REFERRER_READ, true)
                        .apply()
                } catch (_: Exception) {
                    prefs().edit()
                        .putString(KEY_INSTALL_SOURCE, "unknown")
                        .putBoolean(KEY_REFERRER_READ, true)
                        .apply()
                } finally {
                    client.endConnection()
                }
            }

            override fun onInstallReferrerServiceDisconnected() = Unit
        })
    }

    private fun contentCountry(): String {
        prefs().getString(KEY_MANUAL_COUNTRY, null)
            ?.takeIf { it.length == 2 }?.let { return it }
        val telephony = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
        telephony?.simCountryIso?.takeIf { it.length == 2 }
            ?.let { return it.uppercase(Locale.US) }
        telephony?.networkCountryIso?.takeIf { it.length == 2 }
            ?.let { return it.uppercase(Locale.US) }
        return "ZZ"
    }
}
