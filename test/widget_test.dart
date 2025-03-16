// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_link/main.dart';
import 'package:note_link/providers/app_provider.dart';
import 'package:note_link/providers/notes_provider.dart';
import 'package:note_link/providers/themes_provider.dart';

void main() {
  testWidgets('App initializes correctly', (WidgetTester tester) async {
    // Создаем необходимые провайдеры для тестирования
    final appProvider = AppProvider();
    final notesProvider = NotesProvider();
    final themesProvider = ThemesProvider();

    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(
      appProvider: appProvider,
      notesProvider: notesProvider,
      themesProvider: themesProvider,
      isFirstRun: true,
    ));

    // Базовый тест на успешную инициализацию приложения
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
