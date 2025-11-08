// lib/services/notification_service.dart

import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

// ====================================================================
// FUNCIONES GLOBALES REQUERIDAS POR FIREBASE MESSAGING
// ====================================================================

// Handler de Background (Debe ser una función de nivel superior/top-level)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Asegura que Firebase esté inicializado si se lanza en segundo plano.
  await Firebase.initializeApp();
  if (kDebugMode) {
    print("📩 (BG) Mensaje recibido: ${message.notification?.title}");
  }
}

// ====================================================================
// SERVICIO DE NOTIFICACIONES (SINGLETON)
// ====================================================================

class NotificationService {
  // Patrón Singleton para una única instancia.
  static final NotificationService _instance = NotificationService._internal();
  static NotificationService get instance => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const _androidChannelId = 'default_channel';
  static const _androidChannelName = 'Notificaciones Generales';

  /// 🔹 Configura el handler de mensajes en segundo plano.
  static void initBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  /// 🔹 Configura permisos, canales y listeners.
  Future<void> setupPushNotifications() async {
    final messaging = FirebaseMessaging.instance;

    try {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        if (kDebugMode) {
          print('✅ Permisos de notificación concedidos');
          if (Platform.isIOS) {
            String? apnsToken = await messaging.getAPNSToken();
            print('🔑 APNs token: $apnsToken'); 
          }
        }

        // 1. Configuración de Canales (Solo Android)
        if (Platform.isAndroid) {
          const androidChannel = AndroidNotificationChannel(
            _androidChannelId,
            _androidChannelName,
            description: 'Canal principal de Fotocompra',
            importance: Importance.high,
          );

          await _localNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.createNotificationChannel(androidChannel);
        }

        // 2. Inicialización de local_notifications
        const initializationSettings = InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        );
        await _localNotificationsPlugin.initialize(initializationSettings);

        // 3. Listener de mensajes en Primer Plano (Foreground)
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          final notif = message.notification;
          if (notif != null) {
            _showLocalNotification(notif);
          }
        });
      } else {
        if (kDebugMode) {
          print('❌ Permisos de notificación denegados');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('🚨 Error en configuración de notificaciones (no bloqueante): $e');
      }
    }
  }

  /// 🔹 Muestra una notificación local usando el plugin (usado en Foreground).
  Future<void> _showLocalNotification(RemoteNotification notification) async {
    // Usamos las credenciales del canal ya creado en Android
    const androidDetails = AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
    );
  }

  /// 🔹 Guarda el token FCM del usuario en Firestore y maneja el refresh.
  Future<void> saveUserFcmToken({required String familyId}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final messaging = FirebaseMessaging.instance;

    try {
      final token = await messaging.getToken();
      if (token == null) {
        if (kDebugMode) {
          print('⚠️ No hay token FCM disponible todavía.');
        }
        return;
      }

      // Guardar token
      await FirebaseFirestore.instance
          .collection('families')
          .doc(familyId)
          .collection('members')
          .doc(user.uid)
          .set({'fcmToken': token}, SetOptions(merge: true));

      if (kDebugMode) {
        print('💾 Token FCM guardado para ${user.email}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error al guardar FCM token: $e');
      }
    }

    // Listener para la actualización del token
    messaging.onTokenRefresh.listen((newToken) async {
      try {
        await FirebaseFirestore.instance
            .collection('families')
            .doc(familyId)
            .collection('members')
            .doc(user.uid)
            .set({'fcmToken': newToken}, SetOptions(merge: true));
        if (kDebugMode) {
          print('🔄 Token FCM actualizado -> $newToken');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Error al actualizar FCM token: $e');
        }
      }
    });
  }
}