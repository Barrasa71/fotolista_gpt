// lib/services/preferences_service.dart

import 'package:flutter/material.dart'; // Necesario para ValueNotifier
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  // Clave para guardar el factor de escala de la fuente
  static const _fontSizeScaleKey = 'fontSizeScaleFactor';

  // 🟢 1. NOTIFICADOR: Almacena el valor actual y notifica los cambios.
  final ValueNotifier<double> fontScaleNotifier = ValueNotifier(1.0);


  // 🟢 2. INICIALIZADOR: Carga el valor guardado y establece el notificador.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedScale = prefs.getDouble(_fontSizeScaleKey) ?? 1.0; 
    
    // Inicializa el ValueNotifier con el valor guardado.
    fontScaleNotifier.value = savedScale;
  }

  /// 🔹 Guarda el nuevo factor de escala de la fuente
  Future<void> saveFontSizeScaleFactor(double scale) async {
    // Aseguramos que el valor esté en un rango seguro
    final clampedScale = scale.clamp(0.8, 1.8);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeScaleKey, clampedScale);
    
    // 🟢 3. ACTUALIZACIÓN REACTIVA: Esto notifica a todos los oyentes (como MyApp).
    fontScaleNotifier.value = clampedScale; 
  }
  
  // Mantenemos tu getter por si es necesario, aunque el ValueNotifier es la fuente principal
  Future<double> getFontSizeScaleFactor() async {
    return fontScaleNotifier.value; 
  }
}