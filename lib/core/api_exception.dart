import 'package:dio/dio.dart';
import 'i18n.dart';

/// An API failure with a message fit to show staff as is (the server already writes
/// business-rule messages in Arabic).
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.fieldErrors = const {}});

  final String message;
  final int? statusCode;
  final Map<String, List<String>> fieldErrors;

  bool get isUnauthorized => statusCode == 401;

  factory ApiException.from(Object error) {
    if (error is ApiException) return error;
    if (error is String) return ApiException(error);
    if (error is! DioException) return ApiException(tr('حدث خطأ غير متوقع.'));

    final response = error.response;
    if (response == null) {
      return ApiException(tr('تعذّر الاتصال بالخادم. تحقق من الإنترنت وحاول مرة أخرى.'));
    }

    final data = response.data;
    final status = response.statusCode;
    final fields = <String, List<String>>{};
    String? message;

    if (data is Map) {
      message = data['message'] as String?;
      final errors = data['errors'];
      if (errors is Map) {
        errors.forEach((key, value) {
          fields[key.toString()] = (value as List).map((e) => e.toString()).toList();
        });
      }
    }

    // Validation: the first field message is the useful one.
    if (status == 422 && fields.isNotEmpty) {
      message = fields.values.first.first;
    }

    message ??= switch (status) {
      401 => tr('انتهت الجلسة، سجّل الدخول مرة أخرى.'),
      403 => tr('لا تملك صلاحية تنفيذ هذا الإجراء.'),
      404 => tr('العنصر غير موجود.'),
      429 => tr('طلبات كثيرة، انتظر قليلاً ثم حاول مرة أخرى.'),
      _ => tr('حدث خطأ في الخادم ({0}).', [status]),
    };

    return ApiException(message, statusCode: status, fieldErrors: fields);
  }

  @override
  String toString() => message;
}
