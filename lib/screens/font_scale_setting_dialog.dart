import 'package:flutter/material.dart';
import '../services/preferences_service.dart';
// import '../main.dart'; // Ya no es necesario importar MyApp

class FontScaleSettingsDialog extends StatefulWidget {
  final PreferencesService preferencesService;

  const FontScaleSettingsDialog({super.key, required this.preferencesService});

  @override
  State<FontScaleSettingsDialog> createState() => _FontScaleSettingsDialogState();
}

class _FontScaleSettingsDialogState extends State<FontScaleSettingsDialog> {
  // Inicializamos _currentScale con el valor actual del notificador.
  late double _currentScale; 

  @override
  void initState() {
    super.initState();
    // 🟢 Inicialización: Leemos el valor del notificador que ya fue cargado.
    _currentScale = widget.preferencesService.fontScaleNotifier.value;
  }
  
  // 🟢 Función simplificada: Solo guarda el valor en el servicio.
  void _saveAndApplyScale(double newScale) async {
    // 1. Guardar el nuevo valor.
    // El método saveFontSizeScaleFactor AHORA:
    // a) Lo guarda en SharedPreferences.
    // b) Actualiza el ValueNotifier.
    // c) El cambio en el ValueNotifier (en el PreferencesService) notifica a MyApp para reconstruirse. ¡Magia!
    await widget.preferencesService.saveFontSizeScaleFactor(newScale);
    
    // 2. Cerrar el diálogo (el cambio ya se está aplicando automáticamente).
    if(mounted) {
        Navigator.pop(context); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajustar Tamaño de Fuente'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Tamaño de Texto Actual (Ejemplo):'),
          const SizedBox(height: 8),
          Text(
            'Texto de Prueba',
            style: TextStyle(
              // Usamos el factor de escala directamente para el ejemplo visual
              fontSize: 16 * _currentScale, 
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Slider(
            value: _currentScale,
            min: 0.8, // Pequeño (de 80%)
            max: 1.5, // Grande (de 150%)
            divisions: 7, 
            label: '${(_currentScale * 100).round()}%',
            onChanged: (value) {
              setState(() {
                _currentScale = value;
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Pequeño', style: TextStyle(fontSize: 12)),
                Text('Normal', style: TextStyle(fontSize: 12)),
                Text('Grande', style: TextStyle(fontSize: 12)),
              ],
            ),
          )
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => _saveAndApplyScale(_currentScale),
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}