package com.example.yidianban_guide_app

import android.content.Context
import com.alibaba.sdk.android.push.MessageReceiver
import com.alibaba.sdk.android.push.notification.CPushMessage

private const val ALIYUN_PUSH_PREFS = "aliyun_push"
private const val PENDING_ROUTE_KEY = "pending_route"

class AliyunPushReceiver : MessageReceiver() {
  override fun onMessage(context: Context, message: CPushMessage) = Unit

  override fun onNotification(
    context: Context,
    title: String,
    summary: String,
    extraMap: Map<String, String>,
  ) = Unit

  override fun onNotificationOpened(
    context: Context,
    title: String,
    summary: String,
    extraMap: Map<String, String>,
  ) {
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
