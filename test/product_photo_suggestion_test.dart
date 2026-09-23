import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:sari_scan_app/src/models/models.dart';
import 'package:sari_scan_app/src/services/product_photo_suggestion.dart';

TextLine line(String text, double top, double height, {double? confidence}) =>
    TextLine(
      text: text,
      elements: [],
      boundingBox: Rect.fromLTWH(20, top, 220, height),
      recognizedLanguages: [],
      cornerPoints: [],
      confidence: confidence,
      angle: null,
    );

RecognizedText label(List<TextLine> lines) => RecognizedText(
  text: lines.map((line) => line.text).join('\n'),
  blocks: [
    for (final line in lines)
      TextBlock(
        text: line.text,
        lines: [line],
        boundingBox: line.boundingBox,
        recognizedLanguages: [],
        cornerPoints: [],
      ),
  ],
);

Product product(String name) =>
    Product(id: name, name: name, category: 'Milk powder', price: 20, stock: 5);

void main() {
  test('uses label geometry, not OCR block order or nutrition text', () {
    final result = suggestProductFromPhoto(
      label([
        line('Nutrition Facts', 350, 35),
        line('Sodium 20mg', 400, 15),
        line('FORTIFIED', 110, 24),
        line('BEAR BRAND', 50, 45),
        line('Net Wt. 320 g', 180, 15),
        line('Manufactured by Example', 450, 12),
      ]),
      products: [],
    );
    expect(result.name, 'BEAR BRAND FORTIFIED 320 g');
  });

  test('retains brand, variant, and size across three name lines', () {
    final result = suggestProductFromPhoto(
      label([
        line('Nescafé', 20, 40),
        line('CREAMY WHITE', 70, 25),
        line('3 in 1', 110, 20),
        line('29g', 155, 12),
      ]),
      products: [],
    );
    expect(result.name, 'Nescafé CREAMY WHITE 3 in 1 29g');
  });

  test('reuses catalog spelling only for a complete matching label', () {
    final result = suggestProductFromPhoto(
      label([
        line('BEAR BRAND', 20, 40),
        line('FORTIFIED', 70, 25),
        line('320 g', 110, 15),
      ]),
      products: [product('Bear Brand Fortified 320g')],
    );
    expect(result.name, 'Bear Brand Fortified 320g');
    expect(result.category, 'Milk powder');
  });

  test('does not substitute a catalog variant from two shared words', () {
    final result = suggestProductFromPhoto(
      label([
        line('BEAR BRAND', 20, 40),
        line('STERILIZED', 70, 25),
        line('200 ml', 110, 15),
      ]),
      products: [product('Bear Brand Fortified 320g')],
    );
    expect(result.name, 'BEAR BRAND STERILIZED 200 ml');
    expect(result.category, isNull);
  });

  test('does not infer an unread size from the catalog', () {
    final result = suggestProductFromPhoto(
      label([line('BEAR BRAND', 20, 40), line('FORTIFIED', 70, 25)]),
      products: [
        product('Bear Brand Fortified 320g'),
        product('Bear Brand Fortified 700g'),
      ],
    );
    expect(result.name, 'BEAR BRAND FORTIFIED');
  });

  test('ignores small unrelated text, promotions, and distant labels', () {
    final result = suggestProductFromPhoto(
      label([
        line('20% OFF', 0, 70),
        line('MILO', 100, 40),
        line('CHOCOLATE', 155, 25),
        line('Try our other flavors', 195, 10),
        line('OTHER BRAND', 500, 30),
      ]),
      products: [],
    );
    expect(result.name, 'MILO CHOCOLATE');
  });

  test(
    'returns no suggestion for nutrition, instructions, or unclear text',
    () {
      final result = suggestProductFromPhoto(
        label([
          line('Nutrition Facts', 20, 40),
          line('Serving size 30 g', 70, 20),
          line('Store in a cool dry place', 100, 20),
          line('UNREADABLE BRAND', 150, 40, confidence: .2),
        ]),
        products: [],
      );
      expect(result.name, isNull);
      expect(result.category, isNull);
    },
  );

  test('does not guess between conflicting package sizes', () {
    final result = suggestProductFromPhoto(
      label([
        line('Coffee', 20, 40),
        line('100g', 80, 15),
        line('200g', 120, 15),
      ]),
      products: [],
    );
    expect(result.name, 'Coffee');
    expect(result.category, 'Drinks');
  });

  test('does not confuse category substrings or ingredients with the name', () {
    final result = suggestProductFromPhoto(
      label([line('STEAK', 20, 40), line('Ingredients: salt, water', 100, 15)]),
      products: [],
    );
    expect(result.name, 'STEAK');
    expect(result.category, isNull);
  });

  test('keeps legitimate sugar-free variants and short brand names', () {
    final result = suggestProductFromPhoto(
      label([line('RC', 20, 40), line('SUGAR FREE', 70, 25)]),
      products: [],
    );
    expect(result.name, 'RC SUGAR FREE');
  });

  test('handles empty OCR results', () {
    expect(suggestProductFromPhoto(label([]), products: []).name, isNull);
  });

  test('keeps a numeric brand beside a product name, not numbers alone', () {
    expect(
      suggestProductFromPhoto(
        label([line('555', 20, 45), line('SARDINES', 80, 30)]),
        products: [],
      ).name,
      '555 SARDINES',
    );
    expect(
      suggestProductFromPhoto(label([line('555', 20, 45)]), products: []).name,
      isNull,
    );
  });

  test('keeps energy drink labels but excludes nutrient amounts', () {
    final result = suggestProductFromPhoto(
      label([
        line('Brand', 20, 40),
        line('ENERGY DRINK', 70, 25),
        line('Energy 200kcal', 120, 20),
      ]),
      products: [],
    );
    expect(result.name, 'Brand ENERGY DRINK');
    expect(result.category, 'Drinks');
  });
}
