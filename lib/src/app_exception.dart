class AppException implements Exception {
  final String message;

  AppException(this.message);

  @override
  String toString() {
    return message;
  }

  factory AppException.msg(String message) => AppException(message);
}
