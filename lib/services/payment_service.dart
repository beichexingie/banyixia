import 'dart:async';
import 'dart:convert';

import 'package:alipay_payment/alipay_payment.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/payment_config.dart';

enum PaymentOutcome {
  success,
  cancelled,
  failed,
}

class PaymentRequest {
  final String orderId;
  final String merchantOrderNo;
  final double amount;
  final String subject;
  final String paymentMethod;

  const PaymentRequest({
    required this.orderId,
    required this.merchantOrderNo,
    required this.amount,
    required this.subject,
    required this.paymentMethod,
  });
}

class PaymentResult {
  final PaymentOutcome outcome;
  final bool success;
  final String message;
  final String? transactionId;
  final String? paymentUrl;
  final String? orderString;

  const PaymentResult({
    required this.outcome,
    required this.success,
    required this.message,
    this.transactionId,
    this.paymentUrl,
    this.orderString,
  });
}

abstract class PaymentService {
  Future<PaymentResult> pay(PaymentRequest request);
}

class AlipayPaymentService implements PaymentService {
  const AlipayPaymentService();

  static const MethodChannel _alipayEnvChannel = MethodChannel(
    'flutter_application_1/alipay_env',
  );

  @override
  Future<PaymentResult> pay(PaymentRequest request) async {
    try {
      debugPrint('Payment: creating order ${request.orderId}, amount=${request.amount}, sandbox=${PaymentConfig.useSandbox}');
      final data = await _createOrder(request).timeout(const Duration(seconds: 20));

      debugPrint('Payment: backend response data=$data');

      if (data['success'] != true) {
        return PaymentResult(
          outcome: PaymentOutcome.failed,
          success: false,
          message: data['message']?.toString() ?? '支付后端返回失败',
          transactionId: data['payment_request_id']?.toString() ??
              data['transaction_id']?.toString(),
          paymentUrl: data['payment_url']?.toString(),
          orderString: data['order_string']?.toString(),
        );
      }

      final orderString = data['order_string']?.toString() ?? '';
      if (orderString.isEmpty) {
        return const PaymentResult(
          outcome: PaymentOutcome.failed,
          success: false,
          message: '支付参数未生成',
        );
      }

      await AlipayPaymentPlatform.instance.setEnvironment(
        PaymentConfig.useSandbox
            ? AlipayEnvironment.sandbox
            : AlipayEnvironment.production,
      );
      await _alipayEnvChannel.invokeMethod<void>(
        'setAlipayEnv',
        {'sandbox': PaymentConfig.useSandbox},
      );

      final installed = await AlipayPaymentPlatform.instance.isAlipayInstalled();
      if (!installed) {
        return const PaymentResult(
          outcome: PaymentOutcome.failed,
          success: false,
          message: '请先安装支付宝客户端',
        );
      }

      debugPrint('Payment: launching Alipay with order string length=${orderString.length}');
      final resultFuture = AlipayPaymentPlatform.instance.payResp().first;
      await AlipayPaymentPlatform.instance.pay(
        orderInfo: orderString,
        showPayLoading: true,
        payEnv: PaymentConfig.useSandbox
            ? AlipayEnvironment.sandbox
            : AlipayEnvironment.production,
      );
      final payResult = await resultFuture.timeout(
        const Duration(minutes: 2),
        onTimeout: () => AlipayResult.unknown('支付超时'),
      );
      debugPrint('Payment: alipay result success=${payResult.isSuccess}, cancel=${payResult.isCancel}, memo=${payResult.memo}, status=${payResult.resultStatus}');

      if (payResult.isSuccess) {
        return PaymentResult(
          outcome: PaymentOutcome.success,
          success: true,
          message: data['message']?.toString() ?? '支付成功',
          transactionId: data['payment_request_id']?.toString() ??
              data['transaction_id']?.toString(),
          paymentUrl: data['payment_url']?.toString(),
          orderString: orderString,
        );
      }

      if (payResult.isCancel) {
        return PaymentResult(
          outcome: PaymentOutcome.cancelled,
          success: false,
          message: '用户已取消支付',
          transactionId: data['payment_request_id']?.toString() ??
              data['transaction_id']?.toString(),
          paymentUrl: data['payment_url']?.toString(),
          orderString: orderString,
        );
      }

      return PaymentResult(
        outcome: PaymentOutcome.failed,
        success: false,
        message: '支付失败: [${payResult.resultStatus}] ${payResult.memo ?? '未知错误'}',
        transactionId: data['payment_request_id']?.toString() ??
            data['transaction_id']?.toString(),
        paymentUrl: data['payment_url']?.toString(),
        orderString: orderString,
      );
    } catch (e) {
      return PaymentResult(
        outcome: PaymentOutcome.failed,
        success: false,
        message: e is TimeoutException
            ? '支付参数请求超时，请检查函数返回和支付宝回跳配置'
            : '支付请求失败: $e',
      );
    }
  }

  Future<Map<String, dynamic>> _createOrder(PaymentRequest request) async {
    final baseUrl = PaymentConfig.backendBaseUrl.trim().replaceAll(RegExp(r'/$'), '');
    final uri = Uri.parse('$baseUrl/alipay-create-order');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'apikey': PaymentConfig.supabaseAnonKey,
        'Authorization':
            'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken ?? PaymentConfig.supabaseAnonKey}',
      },
      body: jsonEncode({
        'order_id': request.orderId,
        'merchant_order_no': request.merchantOrderNo,
        'amount': request.amount,
        'subject': request.subject,
        'payment_method': request.paymentMethod,
        'sandbox': PaymentConfig.useSandbox,
      }),
    );

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('支付后端返回了不可解析的数据');
    }

    return decoded;
  }
}
