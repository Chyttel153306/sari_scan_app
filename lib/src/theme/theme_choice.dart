enum ThemeChoice {
  defaultTheme('Default'),
  dark('Dark Mode'),
  blue('Blue'),
  red('Red'),
  pink('Pink');

  const ThemeChoice(this.label);
  final String label;

  /// Restores a saved theme name, defaulting when it is missing or unknown.
  static ThemeChoice fromName(Object? name) => values.firstWhere(
    (choice) => choice.name == name,
    orElse: () => defaultTheme,
  );
}
