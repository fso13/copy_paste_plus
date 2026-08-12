import 'package:copy_paste_plus/services/app_settings.dart';
import 'package:copy_paste_plus/services/clipboard_manager.dart';
import 'package:copy_paste_plus/services/theme_service.dart';
import 'package:copy_paste_plus/services/update_service.dart';

final ClipboardManager clipboardManager = ClipboardManager();
final ThemeService themeService = ThemeService();
final UpdateService updateService = UpdateService();
final AppSettings appSettings = AppSettings.instance;
