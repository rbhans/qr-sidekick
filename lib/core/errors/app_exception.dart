/// Base exception class for the app
sealed class AppException implements Exception {
  const AppException(this.message, [this.originalError]);

  final String message;
  final Object? originalError;

  @override
  String toString() => 'AppException: $message';
}

/// Authentication-related exceptions
class AuthException extends AppException {
  const AuthException(super.message, [super.originalError]);
}

/// Network-related exceptions
class NetworkException extends AppException {
  const NetworkException(super.message, [super.originalError]);
}

/// Niagara station connection exceptions
class NiagaraException extends AppException {
  const NiagaraException(super.message, [super.originalError]);
}

/// Equipment not found exception
class EquipmentNotFoundException extends AppException {
  const EquipmentNotFoundException([String? message])
      : super(message ?? 'Equipment configuration not found');
}

/// User not authorized exception
class UnauthorizedException extends AppException {
  const UnauthorizedException([String? message])
      : super(message ?? 'You are not authorized to access this resource');
}

/// Organization not found exception
class OrganizationNotFoundException extends AppException {
  const OrganizationNotFoundException([String? message])
      : super(message ?? 'Organization not found');
}

/// Station unreachable exception
class StationUnreachableException extends NiagaraException {
  const StationUnreachableException([String? message])
      : super(message ?? 'Station is unreachable. Check your network connection.');
}

/// Invalid QR code exception
class InvalidQrCodeException extends AppException {
  const InvalidQrCodeException([String? message])
      : super(message ?? 'Invalid QR code format');
}

/// CSV parsing exception
class CsvParseException extends AppException {
  const CsvParseException(super.message, [super.originalError]);
}
