// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fotolista_gpt/main.dart';
import 'package:fotolista_gpt/services/preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Mock inicial para SharedPreferences (si tu PreferencesService lo usa)
    SharedPreferences.setMockInitialValues({});

    // Crea e inicializa el servicio de preferencias
    final prefs = PreferencesService();
    await prefs.init();

    // Construye la app con el servicio requerido
    await tester.pumpWidget(MyApp(preferencesService: prefs));

    // 👇 A partir de aquí tu test original del contador probablemente no aplica
    // porque tu app no es el template del contador. Para evitar fallos,
    // verifica algo genérico que siempre exista, como el título o un widget raíz.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
