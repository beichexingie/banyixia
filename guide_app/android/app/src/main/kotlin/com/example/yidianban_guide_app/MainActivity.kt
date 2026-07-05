package com.example.yidianban_guide_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

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
  }
}
