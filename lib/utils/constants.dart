// lib/utils/constants.dart
class AppConstants {
  static const String appName = 'CopyPastePlus';
  static const String defaultHotkeyDescription = '⌘⇧C';
  static const int defaultMaxItems = 50;

  /// GitHub repository used for releases / update checks.
  /// Change these if the repo is under a different owner/name.
  static const String githubOwner = 'fso13';
  static const String githubRepo = 'copy_paste_plus';

  static String get githubRepoUrl =>
      'https://github.com/$githubOwner/$githubRepo';

  static String get githubReleasesApiUrl =>
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';

  static String get githubReleasesPageUrl =>
      '$githubRepoUrl/releases/latest';

  /// How often to poll GitHub for a newer release.
  static const Duration updateCheckInterval = Duration(hours: 12);
}
