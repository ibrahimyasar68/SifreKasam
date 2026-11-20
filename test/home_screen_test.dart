import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sifre_kasam/screens/home_screen.dart';
import 'package:sifre_kasam/theme.dart';

void main() {
  testWidgets('home renders', (t) async {
    await t.pumpWidget(MaterialApp(theme: AppTheme.build(Brightness.light), home: const HomeScreen()));
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Şifre Kasam'), findsWidgets);
  });
}
