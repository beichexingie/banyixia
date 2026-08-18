package com.example.flutter_application_1

import android.content.Context
import android.util.Log
import com.alibaba.sdk.android.push.MessageReceiver
import com.alibaba.sdk.android.push.notification.CPushMessage

private const val ALIYUN_PUSH_PREFS = "aliyun_push"
private const val PENDING_ROUTE_KEY = "pending_route"

class AliyunPushReceiver : MessageReceiver() {
  override fun onMessage(context: Context, message: CPushMessage) {
    Log.i("YidianbanPush", "data message received: $message")
  }

  override fun onNotification(
    context: Context,
    title: String,
    summary: String,
    extraMap: Map<String, String>,
  ) {
    Log.i("YidianbanPush", "notification received: title=$title summary=$summary extras=$extraMap")
  }

  override fun onNotificationOpened(
    context: Context,
    title: String,
    summary: String,
    extraMap: Map<String, String>,
  ) {
    Log.i("YidianbanPush", "notification opened: title=$title summary=$summary extras=$extraMap")
    val route = extraMap["route"]?.trim().orEmpty()
    if (route.isNotEmpty()) {
      context.getSharedPreferences(ALIYUN_PUSH_PREFS, Context.MODE_PRIVATE)
        .edit()
        .putString(PENDING_ROUTE_KEY, route)
        .apply()
    }
  }

  override fun onNotificationRemoved(context: Context, messageId: String) = Unit

  override fun showNotificationNow(
    context: Context,
    extraMap: Map<String, String>,
  ): Boolean = false
}
