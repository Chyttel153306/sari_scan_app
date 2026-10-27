enum AppLanguage {
  english('en', 'English'),
  bisaya('ceb', 'Bisaya'),
  tagalog('tl', 'Tagalog');

  const AppLanguage(this.code, this.label);
  final String code;
  final String label;

  /// Restores a saved language code, defaulting to English for unknown values.
  static AppLanguage fromCode(Object? code) => values.firstWhere(
    (language) => language.code == code,
    orElse: () => english,
  );
}
