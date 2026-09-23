enum ThemeChoice {
  defaultTheme('Default'),
  dark('Dark Mode'),
  blue('Blue'),
  red('Red'),
  pink('Pink');

  const ThemeChoice(this.label);
  final String label;

  static ThemeChoice fromName(Object? name) => values.firstWhere(
    (choice) => choice.name == name,
    orElse: () => defaultTheme,
  );
}
