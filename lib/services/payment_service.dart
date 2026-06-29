import 'dart:async';
import 'dart:convert';

import 'package:alipay_payment/alipay_payment.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../config/payment_config.dart';
import 'session_service.dart';

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
      debugPrint(
        'Payment: creating order ${request.orderId}, '
        'amount=${request.amount}, '
        'baseUrl=${PaymentConfig.backendBaseUrl}, '
        'sandbox=${PaymentConfig.useSandbox}',
      );
      final data = await _createOrder(request).timeout(const Duration(seconds: 20));

      debugPrint('Payment: backend response data=$data');

      if (data['success'] != true) {
        return PaymentResult(
          outcome: PaymentOutcome.failed,
          success: false,
          message: data['message']?.toString() ?? 'Payment backend returned failure',
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
          message: 'Payment order string was not generated',
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
          message: 'Please install Alipay first',
        );
      }

      debugPrint(
        'Payment: launching Alipay with order string length=${orderString.length}',
      );
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
        onTimeout: () => AlipayResult.unknown('Payment timeout'),
      );
      debugPrint(
        'Payment: alipay result success=${payResult.isSuccess}, '
        'cancel=${payResult.isCancel}, memo=${payResult.memo}, '
        'status=${payResult.resultStatus}',
      );

      if (payResult.isSuccess) {
        return PaymentResult(
          outcome: PaymentOutcome.success,
          success: true,
          message: data['message']?.toString() ?? 'Payment success',
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
          message: 'User cancelled payment',
          transactionId: data['payment_request_id']?.toString() ??
              data['transaction_id']?.toString(),
          paymentUrl: data['payment_url']?.toString(),
          orderString: orderString,
        );
      }

      return PaymentResult(
        outcome: PaymentOutcome.failed,
        success: false,
        message:
            'Payment failed: [${payResult.resultStatus}] ${payResult.memo ?? 'Unknown error'}',
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
            ? 'Payment parameter request timed out, please check backend callback and Alipay config'
            : 'Payment request failed: $e',
      );
    }
  }

  Future<Map<String, dynamic>> _createOrder(PaymentRequest request) async {
    final baseUrl = PaymentConfig.backendBaseUrl.trim().replaceAll(RegExp(r'/$'), '');
    final uri = Uri.parse('$baseUrl/alipay-create-order');

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'order_id': request.orderId,
        'merchant_order_no': request.merchantOrderNo,
        'amount': request.amount,
        'subject': request.subject,
        'payment_method': request.paymentMethod,
        'sandbox': PaymentConfig.useSandbox,
      }),
    );

    final body = response.body;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception(
          'Payment backend returned non-object JSON. '
          'url=$uri, status=${response.statusCode}',
        );
      }
      return decoded;
    } on FormatException {
      final contentType = response.headers['content-type'] ?? '';
      final preview = _bodyPreview(body);
      debugPrint(
        'Payment create order non-JSON response: '
        'url=$uri, status=${response.statusCode}, contentType=$contentType, body=$preview',
      );
      throw Exception(
        'Payment backend returned non-JSON content. '
        'url=$uri, status=${response.statusCode}, contentType=$contentType, body=$preview',
      );
    }
  }

  String _bodyPreview(String body) {
    final normalized = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return '<empty>';
    }
    if (normalized.length <= 200) {
      return normalized;
    }
    return '${normalized.substring(0, 200)}...';
  }
}
