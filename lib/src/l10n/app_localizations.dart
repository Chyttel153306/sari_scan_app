import 'package:flutter/widgets.dart';

import 'app_language.dart';
import 'translations.dart';

/// The phone's language preference, shared by all routes and dialogs.
class AppLanguageScope extends InheritedWidget {
  const AppLanguageScope({
    super.key,
    required this.language,
    required super.child,
  });
  final AppLanguage language;

  /// Reads the widget tree's language, defaulting to English.
  static AppLanguage of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppLanguageScope>()
          ?.language ??
      AppLanguage.english;

  @override
  bool updateShouldNotify(AppLanguageScope oldWidget) =>
      language != oldWidget.language;
}

/// Also usable outside the widget tree, for example when exporting receipts.
class AppStrings {
  const AppStrings(this.language);
  final AppLanguage language;

  /// Looks up bundled translations and inserts display values without a network call.
  String tr(String message, {List<Object?> args = const []}) {
    final translation = appTranslations[message];
    final result = switch (language) {
      AppLanguage.english => message,
      AppLanguage.bisaya => translation?.$1 ?? message,
      AppLanguage.tagalog => translation?.$2 ?? message,
    };
    // One pass keeps names containing placeholder-like text intact.
    return result.replaceAllMapped(RegExp(r'\{(\d+)\}'), (match) {
      final index = int.parse(match[1]!);
      return index < args.length ? '${args[index]}' : match[0]!;
    });
  }
}

extension AppTranslation on BuildContext {
  AppStrings get strings => AppStrings(AppLanguageScope.of(this));
  String tr(String message, {List<Object?> args = const []}) =>
      strings.tr(message, args: args);
}
