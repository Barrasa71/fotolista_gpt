// lib/main.dart (REVISADO Y LIMPIO)

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Importamos el nuevo servicio de notificaciones y el widget decidor
import 'services/preferences_service.dart';
import 'services/notification_service.dart'; 
import 'screens/main_screen_decider.dart'; // Crearemos este widget en el siguiente paso

// Eliminamos todos los imports y funciones auxiliares de notificaciones

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Inicialización de Firebase
  await Firebase.initializeApp();

  // 2. Configuración del handler de background (ANTES de runApp)
  NotificationService.initBackgroundHandler();
  
  // 3. Inicialización de Preferencias
  final preferencesService = PreferencesService();
  await preferencesService.init(); 

  // 4. Ejecución de la aplicación
  runApp(MyApp(
    preferencesService: preferencesService,
  )); 
  
  // 5. Arranque Secundario: Inicializar notificaciones (después de runApp)
  print('🚀 Inicializando notificaciones...');
  NotificationService.instance.setupPushNotifications();
  print('✅ Notificaciones inicializadas');
}


// 🟢 MYAPP: MANEJA EL TEMA Y LA ESCALA GLOBAL DE TEXTO
class MyApp extends StatefulWidget {
  final PreferencesService preferencesService;

  const MyApp({
    super.key,
    required this.preferencesService,
  });
  
  // (Mantienes este método de acceso estático)
  static MyApp of(BuildContext context) => 
    context.findAncestorWidgetOfExactType<MyApp>()!;


  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  
  @override
  void initState() {
    super.initState();
    // Reconstruye MyApp cuando cambia la escala de texto
    widget.preferencesService.fontScaleNotifier.addListener(_rebuildApp);
  }

  @override
  void dispose() {
    widget.preferencesService.fontScaleNotifier.removeListener(_rebuildApp);
    super.dispose();
  }
  
  void _rebuildApp() {
    setState(() {});
  }


  @override
  Widget build(BuildContext context) {
    // Lectura reactiva del valor del notificador
    final currentScale = widget.preferencesService.fontScaleNotifier.value;
    
    // Configuración de temas
    const seedColor = Colors.teal;

    final lightScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );
    final darkScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'Fotocompra',
      themeMode: ThemeMode.system,
      theme: ThemeData(
          colorScheme: lightScheme, 
          useMaterial3: true,
      ),
      darkTheme: ThemeData(
          colorScheme: darkScheme, 
          useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      
      // Aplicación de la escala global de texto mediante MediaQuery
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(currentScale),
          ),
          child: child!,
        );
      },
      
      // La lógica de decisión de pantalla se ha movido
      home: const MainScreenDecider(),
    );
  }
}

// ❌ El widget MainScreenDecider se ha movido al archivo 'screens/main_screen_decider.dart'