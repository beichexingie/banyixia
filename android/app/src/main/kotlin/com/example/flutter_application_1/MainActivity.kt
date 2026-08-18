package com.example.flutter_application_1

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import com.alibaba.sdk.android.push.CloudPushService
import com.alibaba.sdk.android.push.CommonCallback
import com.alibaba.sdk.android.push.noonesdk.PushServiceFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val ALIYUN_PUSH_CHANNEL = "yidianban/aliyun_push"
private const val ALIYUN_NOTIFICATION_CHANNEL = "yidianban_messages"
private const val ALIYUN_PUSH_PREFS = "aliyun_push"
private const val PENDING_ROUTE_KEY = "pending_route"

class MainActivity : FlutterActivity() {
  private fun applyAlipayEnvironment(sandbox: Boolean) {
    try {
      val envUtilsClass = Class.forName("com.alipay.sdk.app.EnvUtils")
      val envEnumClass = Class.forName("com.alipay.sdk.app.EnvUtils\$EnvEnum")
      val targetEnv = java.lang.Enum.valueOf(
        envEnumClass.asSubclass(Enum::class.java) as Class<out Enum<*>>,
        if (sandbox) "SANDBOX" else "ONLINE",
      )
      val setEnvMethod = envUtilsClass.getMethod("setEnv", envEnumClass)
      setEnvMethod.invoke(null, targetEnv)
    } catch (_: Throwable) {
      // Ignore here; Dart side will still surface payment failures if env switching is unavailable.
    }
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger,
      "flutter_application_1/alipay_env",
    ).setMethodCallHandler { call, result ->
      when (call.method) {
        "setAlipayEnv" -> {
          val sandbox = call.argument<Boolean>("sandbox") ?: false
          applyAlipayEnvironment(sandbox)
          result.success(null)
        }
        else -> result.notImplemented()
      }
    }

    MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger,
      ALIYUN_PUSH_CHANNEL,
    ).setMethodCallHandler { call, result ->
      when (call.method) {
        "initialize" -> {
          Log.i("YidianbanPush", "initialize requested")
          val appKey = BuildConfig.ALIYUN_PUSH_APP_KEY.trim()
          val appSecret = BuildConfig.ALIYUN_PUSH_APP_SECRET.trim()
          if (appKey.isEmpty() || appSecret.isEmpty()) {
            result.error("missing_config", "Aliyun Push AppKey/AppSecret is missing", null)
          } else {
            initializeAliyunPush(appKey, appSecret, result)
          }
        }
        "bindAccount" -> {
          val userId = call.argument<String>("userId")?.trim().orEmpty()
          if (userId.isEmpty()) {
            result.error("missing_user", "A user id is required", null)
          } else {
            bindAliyunAccount(userId, result)
          }
        }
        "consumePendingRoute" -> {
          val prefs = getSharedPreferences(ALIYUN_PUSH_PREFS, Context.MODE_PRIVATE)
          val route = prefs.getString(PENDING_ROUTE_KEY, null)
          prefs.edit().remove(PENDING_ROUTE_KEY).apply()
          result.success(route)
        }
        else -> result.notImplemented()
      }
    }
  }

  private fun initializeAliyunPush(
    appKey: String,
    appSecret: String,
    result: MethodChannel.Result,
  ) {
    try {
      PushServiceFactory.init(applicationContext)
      val pushService = PushServiceFactory.getCloudPushService()
      pushService.setAppkey(appKey)
      pushService.setAppSecret(appSecret)
      pushService.setDebug(BuildConfig.DEBUG)
      pushService.setNotificationSmallIcon(R.mipmap.ic_launcher)
      ensurePushNotificationChannel()
      requestPushNotificationPermission()
      pushService.register(applicationContext, object : CommonCallback {
        override fun onSuccess(response: String?) {
          pushService.onAppStart()
          val deviceId = pushService.deviceId.orEmpty()
          Log.i(
            "YidianbanPush",
            "registered deviceId=${deviceId.take(12)} response=${response ?: "-"}",
          )
          runOnUiThread {
            if (deviceId.isEmpty()) {
              result.error("empty_device_id", "Aliyun Push returned no DeviceId", response)
            } else {
              result.success(mapOf("deviceId" to deviceId))
            }
          }
        }

        override fun onFailed(errorCode: String?, errorMessage: String?) {
          Log.e("YidianbanPush", "registration failed: $errorCode $errorMessage")
          runOnUiThread {
            result.error(errorCode ?: "register_failed", errorMessage, null)
          }
        }
      })
    } catch (error: Throwable) {
      result.error("initialize_failed", error.message, null)
    }
  }

  private fun bindAliyunAccount(userId: String, result: MethodChannel.Result) {
    try {
      val pushService: CloudPushService = PushServiceFactory.getCloudPushService()
      pushService.bindAccount(userId, object : CommonCallback {
        override fun onSuccess(response: String?) {
          Log.i(
            "YidianbanPush",
            "account bound user=${userId.take(8)} response=${response ?: "-"}",
          )
          runOnUiThread { result.success(null) }
        }

        override fun onFailed(errorCode: String?, errorMessage: String?) {
          Log.e("YidianbanPush", "account bind failed: $errorCode $errorMessage")
          runOnUiThread {
            result.error(errorCode ?: "bind_failed", errorMessage, null)
          }
        }
      })
    } catch (error: Throwable) {
      result.error("bind_failed", error.message, null)
    }
  }

  private fun ensurePushNotificationChannel() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
    val channel = NotificationChannel(
      ALIYUN_NOTIFICATION_CHANNEL,
      "Yidianban messages",
      NotificationManager.IMPORTANCE_HIGH,
    )
    getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
  }

  private fun requestPushNotificationPermission() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
      checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) !=
        PackageManager.PERMISSION_GRANTED
    ) {
      requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 1001)
    }
  }
}
