// lib/main.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'screens/auth_screen.dart';
import 'screens/biometric_lock_screen.dart';
import 'screens/family_selection_screen.dart';
import 'services/preferences_service.dart';

// ... (El resto de las funciones auxiliares _firebaseMessagingBackgroundHandler, 
// _setupPushNotifications, saveUserFcmToken permanecen IGUAL) ...
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("📩 (BG) Mensaje recibido: ${message.notification?.title}");
}

Future<void> _setupPushNotifications() async {
  final messaging = FirebaseMessaging.instance;

  try {
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Permisos de notificación concedidos');

      if (Platform.isIOS) {
        try {
          String? apnsToken = await messaging.getAPNSToken();
          print('🔑 APNs token inicial: $apnsToken');

          if (apnsToken == null) {
            for (int retries = 0; retries < 5; retries++) {
              await Future.delayed(const Duration(seconds: 2));
              apnsToken = await messaging.getAPNSToken();
              print('⏳ Reintentando obtener APNs token... intento ${retries + 1}');
              if (apnsToken != null) break;
            }
          }

          if (apnsToken == null) {
            print('⚠️ No se obtuvo token APNs tras varios intentos. Continuando sin él.');
          } else {
            print('✅ APNs token obtenido correctamente.');
          }
        } catch (e) {
          print('⚠️ Error silencioso al obtener APNs token: $e');
        }
      }

      try {
        final token = await messaging.getToken();
        print('📱 Token FCM: $token');
      } catch (e) {
        print('⚠️ Error al obtener token FCM: $e');
      }

      if (Platform.isAndroid) {
        const androidChannel = AndroidNotificationChannel(
          'default_channel',
          'Notificaciones Generales',
          description: 'Canal principal de Fotocompra',
          importance: Importance.high,
        );

        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(androidChannel);
      }
    } else {
      print('❌ Permisos de notificación denegados');
    }

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notif = message.notification;
      if (notif != null) {
        flutterLocalNotificationsPlugin.show(
          notif.hashCode,
          notif.title,
          notif.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'default_channel',
              'Notificaciones Generales',
              icon: notif.android?.smallIcon,
            ),
            iOS: const DarwinNotificationDetails(),
          ),
        );
      }
    });
  } catch (e) {
    print('🚨 Error en configuración de notificaciones (no bloqueante): $e');
  }
}

Future<void> saveUserFcmToken({required String familyId}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) {
      print('⚠️ No hay token FCM disponible todavía (iOS sin APNs).');
      return;
    }

    await FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('members')
        .doc(user.uid)
        .set({'fcmToken': token}, SetOptions(merge: true));

    print('💾 Token FCM guardado para ${user.email} -> $token');
  } catch (e) {
    print('⚠️ Error al guardar FCM token: $e');
  }

  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    try {
      await FirebaseFirestore.instance
          .collection('families')
          .doc(familyId)
          .collection('members')
          .doc(user.uid)
          .set({'fcmToken': newToken}, SetOptions(merge: true));
      print('🔄 Token FCM actualizado -> $newToken');
    } catch (e) {
      print('⚠️ Error al actualizar FCM token: $e');
    }
  });
}
// ... (Fin de las funciones auxiliares) ...


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  print('🚀 Inicializando notificaciones...');
  _setupPushNotifications(); 
  print('✅ Notificaciones inicializadas');

  // 🟢 LECTURA Y CONFIGURACIÓN INICIAL DE PREFERENCIAS
  final preferencesService = PreferencesService();
  // Llamamos a init para cargar la escala inicial en el ValueNotifier
  await preferencesService.init(); 

  // 🟢 PASAMOS LA INSTANCIA DEL SERVICIO A MYAPP
  runApp(MyApp(
    preferencesService: preferencesService,
    // Eliminamos initialScaleFactor, MyApp lo leerá del ValueNotifier
  )); 
}


// 🟢 MYAPP: ES ESTADO DINÁMICO, SE SUSCRIBE AL NOTIFICADOR PARA RECONSTRUIRSE
class MyApp extends StatefulWidget {
  final PreferencesService preferencesService;

  const MyApp({
    super.key,
    required this.preferencesService,
  });
  
  // 🟢 Método estático para obtener el servicio desde el contexto
  static MyApp of(BuildContext context) => 
    context.findAncestorWidgetOfExactType<MyApp>()!;


  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  
  // 🟢 1. SUSCRIPCIÓN: Añadir oyente al ValueNotifier
  @override
  void initState() {
    super.initState();
    // Cuando el valor del notificador cambie, llamamos a _rebuildApp
    widget.preferencesService.fontScaleNotifier.addListener(_rebuildApp);
  }

  // 🟢 2. LIMPIEZA: Eliminar oyente al destruir el widget
  @override
  void dispose() {
    widget.preferencesService.fontScaleNotifier.removeListener(_rebuildApp);
    super.dispose();
  }
  
  // 🟢 3. RECONSTRUCCIÓN: Fuerza el rebuild de MyApp
  void _rebuildApp() {
    setState(() {});
  }


  @override
  Widget build(BuildContext context) {
    // 🟢 4. OBTENER VALOR ACTUAL: Leemos el valor reactivo del notificador
    final currentScale = widget.preferencesService.fontScaleNotifier.value;
    
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
          // Eliminamos la aplicación de la escala aquí. Se hace en el builder.
      ),
      darkTheme: ThemeData(
          colorScheme: darkScheme, 
          useMaterial3: true,
          // Eliminamos la aplicación de la escala aquí. Se hace en el builder.
      ),
      debugShowCheckedModeBanner: false,
      
      // 🟢 5. APLICACIÓN DE LA ESCALA GLOBAL: Usamos el builder
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            // textScaleFactor es la propiedad que Flutter usa para escalar
            // textScaleFactor: currentScale, 
            // textScaler es la propiedad moderna (a partir de Flutter 3.16)
            textScaler: TextScaler.linear(currentScale),
          ),
          child: child!,
        );
      },
      
      home: const MainScreenDecider(),
    );
  }
}

class MainScreenDecider extends StatelessWidget {
  const MainScreenDecider({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        if (snapshot.data != null) {
          return const BiometricLockScreen(
            child: FamilySelectionScreen(),
          );
        }

        if (snapshot.connectionState == ConnectionState.active && snapshot.data == null) {
          return const AuthScreen();
        }
        
        return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}