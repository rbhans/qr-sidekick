/// App-wide constants
class AppConstants {
  AppConstants._();

  static const String appName = 'QR Sidekick';
  static const String appVersion = '1.0.0';

  /// Deep link scheme for invitation links
  static const String deepLinkScheme = 'qrsidekick';

  /// Invitation expiry duration
  static const Duration invitationExpiry = Duration(days: 7);

  /// Network timeout duration
  static const Duration networkTimeout = Duration(seconds: 30);

  /// Refresh interval for live data
  static const Duration liveDataRefreshInterval = Duration(seconds: 30);
}
