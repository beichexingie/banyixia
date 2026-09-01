package com.example.flutter_application_1

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.util.Log
import com.amap.api.location.AMapLocationClient
import com.amap.api.location.AMapLocationClientOption
import com.amap.api.location.AMapLocationListener
import com.alibaba.sdk.android.push.CloudPushService
import com.alibaba.sdk.android.push.CommonCallback
import com.alibaba.sdk.android.push.noonesdk.PushServiceFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val ALIYUN_PUSH_CHANNEL = "yidianban/aliyun_push"
private const val ALIYUN_NOTIFICATION_CHANNEL = "yidianban_messages"
private const val ALIYUN_ORDER_NOTIFICATION_CHANNEL = "yidianban_orders"
private const val ALIYUN_PUSH_PREFS = "aliyun_push"
private const val PENDING_ROUTE_KEY = "pending_route"
private const val AMAP_LOCATION_CHANNEL = "flutter_application_1/amap_location"

class MainActivity : FlutterActivity() {
  private var notificationPermissionRequested = false

  override fun onPostResume() {
    super.onPostResume()
    // Request independently from Aliyun Push initialization. Push setup may
    // happen later (for example, after login), while Android requires a
    // resumed Activity to show the permission dialog reliably.
    window.decorView.postDelayed({
      requestPushNotificationPermission()
      logNotificationState()
    }, 600)
  }

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
      AMAP_LOCATION_CHANNEL,
    ).setMethodCallHandler { call, result ->
      when (call.method) {
        "getCurrentLocation" -> requestAmapLocation(result)
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
        "requestNotificationPermission" -> {
          requestPushNotificationPermission()
          result.success(notificationPermissionState())
        }
        "openNotificationSettings" -> {
          openNotificationSettings()
          result.success(null)
        }
        "notificationPermissionState" -> {
          result.success(notificationPermissionState())
        }
        else -> result.notImplemented()
      }
    }
  }

  private fun requestAmapLocation(result: MethodChannel.Result) {
    var locationClient: AMapLocationClient? = null
    var delivered = false
    val timeoutHandler = android.os.Handler(android.os.Looper.getMainLooper())
    fun cleanup() {
      timeoutHandler.removeCallbacksAndMessages(null)
      locationClient?.stopLocation()
      locationClient?.onDestroy()
      locationClient = null
    }
    fun finishError(code: String, message: String) {
      if (delivered) return
      delivered = true
      cleanup()
      runOnUiThread { result.error(code, message, null) }
    }
    fun finishSuccess(location: com.amap.api.location.AMapLocation) {
      if (delivered) return
      delivered = true
      cleanup()
      runOnUiThread {
        result.success(
          mapOf(
            "latitude" to location.latitude,
            "longitude" to location.longitude,
            "accuracy" to location.accuracy,
            "altitude" to location.altitude,
            "bearing" to location.bearing,
            "speed" to location.speed,
            "coordinateSystem" to "gcj02",
          ),
        )
      }
    }
    try {
      AMapLocationClient.updatePrivacyShow(applicationContext, true, true)
      AMapLocationClient.updatePrivacyAgree(applicationContext, true)
      val option = AMapLocationClientOption().apply {
        locationMode = AMapLocationClientOption.AMapLocationMode.Hight_Accuracy
        isOnceLocation = true
        isOnceLocationLatest = true
        isNeedAddress = false
      }
      locationClient = AMapLocationClient(applicationContext).apply {
        setLocationOption(option)
        setLocationListener(AMapLocationListener { location ->
          if (location == null) {
            finishError("AMAP_NULL_RESULT", "高德返回空定位结果")
          } else if (location.errorCode == 0 && location.latitude != 0.0 && location.longitude != 0.0) {
            finishSuccess(location)
          } else {
            finishError(
              "AMAP_LOCATION_${location.errorCode}",
              location.errorInfo?.toString() ?: "高德定位失败",
            )
          }
        })
        startLocation()
      }
      timeoutHandler.postDelayed(
        { finishError("AMAP_LOCATION_TIMEOUT", "高德定位超时") },
        16000,
      )
    } catch (error: Throwable) {
      finishError("AMAP_LOCATION_ERROR", error.message ?: "高德定位初始化失败")
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
      logNotificationState()
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
    val messagesChannel = NotificationChannel(
      ALIYUN_NOTIFICATION_CHANNEL,
      "Yidianban messages",
      NotificationManager.IMPORTANCE_HIGH,
    )
    val orderChannel = NotificationChannel(
      ALIYUN_ORDER_NOTIFICATION_CHANNEL,
      "Yidianban orders",
      NotificationManager.IMPORTANCE_HIGH,
    )
    val soundId = resources.getIdentifier("order_new", "raw", packageName)
    if (soundId != 0) {
      val soundUri = Uri.parse("android.resource://$packageName/$soundId")
      val attributes = android.media.AudioAttributes.Builder()
        .setUsage(android.media.AudioAttributes.USAGE_NOTIFICATION)
        .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build()
      orderChannel.setSound(soundUri, attributes)
    } else {
      Log.w("YidianbanPush", "order_new sound resource missing; order notifications use system sound")
    }
    getSystemService(NotificationManager::class.java).createNotificationChannels(
      listOf(messagesChannel, orderChannel),
    )
  }

  private fun logNotificationState() {
    val state = notificationPermissionState()
    Log.i(
      "YidianbanPush",
      "notification state enabled=${state["enabled"]} permission=${state["permission"]} " +
        "channel=$ALIYUN_NOTIFICATION_CHANNEL importance=${state["channelImportance"]}",
    )
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      Log.i(
        "YidianbanPush",
        "order notification channel importance=${state["orderChannelImportance"]} " +
          "sound=${state["orderChannelSound"]}",
      )
    }
  }

  private fun notificationPermissionState(): Map<String, Any> {
    val manager = getSystemService(NotificationManager::class.java)
    val enabled = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
      manager.areNotificationsEnabled()
    } else {
      true
    }
    val channelImportance = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      manager.getNotificationChannel(ALIYUN_NOTIFICATION_CHANNEL)?.importance ?: -1
    } else {
      -1
    }
    return mapOf(
      "enabled" to enabled,
      "permission" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
          PackageManager.PERMISSION_GRANTED
      } else {
        enabled
      },
      "channelImportance" to channelImportance,
      "orderChannelImportance" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        manager.getNotificationChannel(ALIYUN_ORDER_NOTIFICATION_CHANNEL)?.importance ?: -1
      } else {
        -1
      },
      "orderChannelSound" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        manager.getNotificationChannel(ALIYUN_ORDER_NOTIFICATION_CHANNEL)?.sound?.toString() ?: "default"
      } else {
        "default"
      },
    )
  }

  private fun requestPushNotificationPermission() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
      !notificationPermissionRequested &&
      checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) !=
        PackageManager.PERMISSION_GRANTED
    ) {
      notificationPermissionRequested = true
      Log.i("YidianbanPush", "requesting POST_NOTIFICATIONS permission")
      requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 1001)
    }
  }

  private fun openNotificationSettings() {
    val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
      putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
      data = Uri.parse("package:$packageName")
    }
    startActivity(intent)
  }
}
