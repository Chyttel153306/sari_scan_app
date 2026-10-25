/// Peso amounts use two decimal places; avoid residual binary-float fractions.
double roundMoney(double value) => double.parse(value.toStringAsFixed(2));
