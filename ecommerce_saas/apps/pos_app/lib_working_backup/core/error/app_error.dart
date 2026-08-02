class AppError implements Exception {
  final String message;
  final String? code;

  AppError(this.message, {this.code});

  @override
  String toString() => message;
}

class NetworkError extends AppError {
  NetworkError([String? message]) : super(message ?? 'خطأ في الاتصال بالشبكة. يرجى التأكد من الإنترنت.');
}

class AuthError extends AppError {
  AuthError([String? message]) : super(message ?? 'خطأ في المصادقة. يرجى تسجيل الدخول مرة أخرى.');
}

class PermissionError extends AppError {
  PermissionError([String? message]) : super(message ?? 'ليس لديك الصلاحيات الكافية لإتمام هذه العملية.');
}

class ServerError extends AppError {
  ServerError([String? message]) : super(message ?? 'حدث خطأ في الخادم. يرجى المحاولة لاحقاً.');
}
