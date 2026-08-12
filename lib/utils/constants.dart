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

  /// Public docs site (GitHub Pages).
  static String get docsSiteUrl =>
      'https://$githubOwner.github.io/$githubRepo/';

  /// How often to poll GitHub for a newer release.
  static const Duration updateCheckInterval = Duration(hours: 12);

  /// Bundle IDs that typically hold secrets — ignored from history by default.
  static const Set<String> passwordManagerBundleIds = {
    'com.1password.1password',
    'com.1password.1password-launcher',
    'com.agilebits.onepassword7',
    'com.agilebits.onepassword-safari-v2',
    'com.bitwarden.desktop',
    'com.bitwarden.desktop.safari',
    'com.lastpass.LastPass',
    'com.dashlane.dashlanephonefinal',
    'org.keepassx.keepassxc',
    'com.apple.keychainaccess',
    'com.nordpass.macos.NordPass',
    'com.enpass.desktop',
    'com.protonpass.safari',
  };

  /// Default ignore list (password managers + a few common vault UIs).
  static const Set<String> defaultIgnoredBundleIds = {
    ...passwordManagerBundleIds,
  };
}
