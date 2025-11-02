// lib/screens/family_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

import 'package:fotolista_gpt/screens/auth_screen.dart';
import 'package:fotolista_gpt/screens/family_qr_screen.dart';
import 'package:fotolista_gpt/screens/family_settings_screen.dart';
import 'package:fotolista_gpt/screens/shopping_list/shopping_item_screen.dart';

// 🟢 Importaciones Correctas de Servicios:
import 'package:fotolista_gpt/services/family_services.dart';
import 'package:fotolista_gpt/services/firestore_service.dart'; // Mantenemos solo para métodos atómicos (deleteFamily)
import 'package:fotolista_gpt/services/storage_service.dart';
import 'package:fotolista_gpt/widgets/cached_firebase_image.dart';
import '../models/family.dart';
import 'family_qr_scanner.dart';

class FamilySelectionScreen extends StatefulWidget {
  const FamilySelectionScreen({super.key});

  @override
  State<FamilySelectionScreen> createState() => _FamilySelectionScreenState();
}

class _FamilySelectionScreenState extends State<FamilySelectionScreen> {
  // 🟢 Corregido: Usamos el FamilyService de alto nivel para lógica de familia
  final FamilyService _familyService = FamilyService();
  // 🟢 Mantenemos FirestoreService para operaciones de borrado complejas (ej. deleteFamily)
  final FirestoreService _db = FirestoreService();
  final StorageService _storage = StorageService();

  final TextEditingController _familyNameController = TextEditingController();
  final TextEditingController _joinCodeController = TextEditingController();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _setupPushNotifications();
  }

  // --- MÉTODOS AUXILIARES ---

  Future<void> _setupPushNotifications() async {
    await FirebaseMessaging.instance.requestPermission();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);
    await _localNotificationsPlugin.initialize(initSettings);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        _showLocalNotification(notification);
      }
    });
  }

  Future<void> _showLocalNotification(RemoteNotification notification) async {
    const androidDetails = AndroidNotificationDetails(
      'default_channel',
      'Notificaciones',
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

  @override
  void dispose() {
    _familyNameController.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }

  // 🟢 CORRECCIÓN CLAVE: Usar _familyService para crear la familia
  Future<void> _createFamily() async {
    final name = _familyNameController.text.trim();
    if (name.isEmpty) return;
    
    // Antes: await _db.createFamily(name);
    // Ahora:
    await _familyService.createFamily(name); 
    
    _familyNameController.clear();
    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  // 🟢 El método _joinFamily ya usaba _familyService (¡Perfecto!)
  Future<void> _joinFamily() async {
    final code = _joinCodeController.text.trim();
    if (code.isEmpty) return;
    await _familyService.joinFamily(code);
    _joinCodeController.clear();
    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _openFamily(String familyId) async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic('family_$familyId');
    } catch (e) {
      // Manejo de error de subscripción
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShoppingItemScreen(familyId: familyId),
      ),
    );
  }

  // --- FUNCIONES DE DIÁLOGO MODERNIZADAS (sin cambios de lógica) ---

  Future<void> _showCreateFamilyDialog() async {
    final theme = Theme.of(context);
    return showDialog(
      context: context,
      builder: (context) {
        _familyNameController.clear();
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.family_restroom, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              const Text("Crear Nueva Familia"),
            ],
          ),
          content: TextField(
            controller: _familyNameController,
            decoration: InputDecoration(
              labelText: "Nombre de la familia",
              prefixIcon: Icon(Icons.group_outlined,
                  color: theme.colorScheme.secondary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            FilledButton(
              onPressed: _createFamily,
              child: const Text("Crear"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showJoinFamilyDialog() async {
    final theme = Theme.of(context);
    return showDialog(
      context: context,
      builder: (context) {
        _joinCodeController.clear();
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.group_add, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              const Text("Unirse a una Familia"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _joinCodeController,
                decoration: InputDecoration(
                  labelText: "Código de familia",
                  prefixIcon: Icon(Icons.vpn_key_outlined,
                      color: theme.colorScheme.secondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context); // Cierra el diálogo
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FamilyQrScanner(),
                    ),
                  );
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text("Escanear Código QR"),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 45),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: theme.colorScheme.primary),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            FilledButton(
              onPressed: _joinFamily,
              child: const Text("Unirse con Código"),
            ),
          ],
        );
      },
    );
  }

  // --- WIDGET PRINCIPAL ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        title: const Text("Familias"),
        automaticallyImplyLeading: false,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Cerrar sesión",
            onPressed: () async {
              try {
                // Desuscribirse de todos los topics de familia antes de salir
                final families = await _familyService.getUserFamilies().first;
                for (final family in families) {
                  try {
                    await FirebaseMessaging.instance
                        .unsubscribeFromTopic('family_${family.id}');
                  } catch (_) {}
                }
              } catch (_) {}

              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const AuthScreen()),
                  (Route<dynamic> route) => false,
                );
              }
            },
          ),
        ],
      ),

      body: StreamBuilder<List<Family>>(
        stream: _familyService.getUserFamilies(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final families = snapshot.data ?? [];

          if (families.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.group_off_outlined,
                        size: 80, color: theme.colorScheme.outline),
                    const SizedBox(height: 16),
                    Text(
                      "No perteneces a ninguna familia.",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(color: theme.colorScheme.onSurface),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Toca el botón '+' para crear una nueva o unirte a una existente.",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              // 🟢 Encabezado Moderno
              Text(
                "Tus Espacios de Compra",
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              // 🟢 Listado de Tarjetas
              ...families.map((family) {
                final colorSeed = family.id.codeUnits.fold(0, (a, b) => a + b);
                final fallbackColor =
                    Colors.primaries[colorSeed % Colors.primaries.length];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  // 🟢 Dismissible con mejor feedback de color
                  child: Dismissible(
                    key: Key(family.id),
                    direction: DismissDirection.horizontal,
                    background: Container(
                      color: theme.colorScheme.secondaryContainer, // Color suave
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 24),
                      child: Icon(Icons.settings,
                          color: theme.colorScheme.onSecondaryContainer,
                          size: 28),
                    ),
                    secondaryBackground: Container(
                      color: theme.colorScheme.errorContainer, // Color de error
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      child: Icon(Icons.delete_forever,
                          color: theme.colorScheme.onErrorContainer, size: 28),
                    ),
                    confirmDismiss: (direction) async {
                      if (direction == DismissDirection.startToEnd) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FamilySettingsScreen(
                              familyId: family.id,
                              currentName: family.name,
                            ),
                          ),
                        );
                        return false;
                      }
                      if (direction == DismissDirection.endToStart) {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text("¿Eliminar familia?"),
                            content: Text(
                                "Se eliminarán todos los datos de '${family.name}'. ¿Estás seguro?"),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text("Cancelar"),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                    backgroundColor: theme.colorScheme.error),
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text("Eliminar",
                                    style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          // 🟢 Mantenemos el borrado de imagen y de familia en los servicios de bajo nivel.
                          await _storage.deleteFamilyImage(family.id);
                          await _db.deleteFamily(family.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Familia '${family.name}' eliminada",
                                ),
                              ),
                            );
                          }
                        }
                        return confirm;
                      }
                      return false;
                    },
                    // 🟢 Tarjeta Moderna
                    child: Card(
                      elevation: 4, // Resaltar la tarjeta
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _openFamily(family.id),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 8),
                          // 🟢 CORRECCIÓN: Usar el servicio correcto para obtener la imagen si el método existe.
                          // Si getFamilyImage no está en _db, debe estar en _storage o _familyService.
                          // Asumo que getFamilyImage sigue en FirestoreService para obtener solo la URL.
                          child: FutureBuilder<String?>(
                            future: _db.getFamilyImage(family.id),
                            builder: (context, snap) {
                              final imageUrl = snap.data;
                              
                              return ListTile(
                                leading: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => FamilySettingsScreen(
                                          familyId: family.id,
                                          currentName: family.name,
                                        ),
                                      ),
                                    );
                                  },
                                  child: imageUrl != null
                                      ? SizedBox( // 🟢 CORRECCIÓN APLICADA: Usamos SizedBox y ClipOval
                                          width: 48, 
                                          height: 48,
                                          child: ClipOval(
                                            child: CachedFirebaseImage(
                                              imageUrl: imageUrl,
                                            ),
                                          ),
                                        )
                                      : CircleAvatar(
                                          radius: 24,
                                          backgroundColor: fallbackColor,
                                          child: const Icon(Icons.group,
                                              color: Colors.white),
                                        ),
                                ),
                                title: Text(
                                  family.name,
                                  style: theme.textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  "Toca para abrir la lista",
                                  style: theme.textTheme.bodyMedium,
                                ),
                                trailing: IconButton(
                                  icon: Icon(Icons.qr_code,
                                      color: theme.colorScheme.secondary),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => FamilyQrScreen(
                                            familyId: family.id),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          );
        },
      ),

      // 🟢 Botón Flotante (SpeedDial)
      floatingActionButton: SpeedDial(
        icon: Icons.add,
        activeIcon: Icons.close,
        backgroundColor: theme.colorScheme.secondary,
        foregroundColor: theme.colorScheme.onSecondary,
        overlayOpacity: 0.5,
        spacing: 10,
        spaceBetweenChildren: 8,
        children: [
          // Opción 1: Crear Nueva Familia
          SpeedDialChild(
            child: const Icon(Icons.create_new_folder),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            label: 'Crear Nueva Familia',
            onTap: _showCreateFamilyDialog,
          ),
          // Opción 2: Unirse a Familia
          SpeedDialChild(
            child: const Icon(Icons.group_add),
            backgroundColor: theme.colorScheme.tertiary,
            foregroundColor: theme.colorScheme.onTertiary,
            label: 'Unirse a Familia',
            onTap: _showJoinFamilyDialog,
          ),
        ],
      ),
    );
  }
}