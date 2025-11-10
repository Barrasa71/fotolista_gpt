// lib/screens/family_selection_screen.dart (REVISADO Y LIMPIO)

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

// Importamos el nuevo widget FamilyCard y el servicio de notificaciones
import 'package:fotolista_gpt/services/notification_service.dart';
import 'package:fotolista_gpt/widgets/family_card.dart'; // ¡Nuevo!

import 'package:fotolista_gpt/screens/auth_screen.dart';
import 'package:fotolista_gpt/screens/shopping_list/shopping_item_screen.dart';
import 'package:fotolista_gpt/services/family_services.dart';
import '../models/family.dart';
import 'family_qr_scanner.dart';

class FamilySelectionScreen extends StatefulWidget {
  const FamilySelectionScreen({super.key});

  @override
  State<FamilySelectionScreen> createState() => _FamilySelectionScreenState();
}

class _FamilySelectionScreenState extends State<FamilySelectionScreen> {
  final FamilyService _familyService = FamilyService(); // Asegúrate que FamilyService sea const si es posible
  // Nota: Ya no necesitamos FirestoreService ni StorageService aquí, ¡los movimos a FamilyCard!

  final TextEditingController _familyNameController = TextEditingController();
  final TextEditingController _joinCodeController = TextEditingController();

  @override
  void dispose() {
    _familyNameController.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }

  // --- LÓGICA DE NAVEGACIÓN Y ACCIONES ---

  void _showFamilyDeletedSnackbar(String familyName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Familia '$familyName' eliminada"),
      ),
    );
  }

  Future<void> _openFamily(String familyId) async {
    // 1. Guardar/actualizar token FCM para recibir notificaciones
    NotificationService.instance.saveUserFcmToken(familyId: familyId);

    // 2. Suscripción al topic para notificaciones de lista
    try {
      await FirebaseMessaging.instance.subscribeToTopic('family_$familyId');
    } catch (_) {
      // Manejo de error de subscripción (no bloqueante)
    }

    if (!mounted) return;
    // 3. Navegación a la lista de compra
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShoppingItemScreen(familyId: familyId),
      ),
    );
  }
  
  // (Mantenemos _createFamily y _joinFamily ya que son la lógica de negocio)

  Future<void> _createFamily() async {
    final name = _familyNameController.text.trim();
    if (name.isEmpty) return;
    
    await _familyService.createFamily(name); 
    
    _familyNameController.clear();
    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _joinFamily() async {
    final code = _joinCodeController.text.trim();
    if (code.isEmpty) return;
    await _familyService.joinFamily(code);
    _joinCodeController.clear();
    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  // (Mantenemos _showCreateFamilyDialog y _showJoinFamilyDialog)

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

  // --- WIDGET PRINCIPAL LIMPIO ---

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
                // Desuscribirse de todos los topics antes de salir
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
            // ... (El widget de lista vacía se mantiene igual)
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

          // 🟢 USO DEL WIDGET MODULARIZADO
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              Text(
                "Tus Espacios de Compra",
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              ...families.map((family) {
                return FamilyCard(
                  family: family,
                  onFamilyOpened: () => _openFamily(family.id),
                  onFamilyDeleted: () => _showFamilyDeletedSnackbar(family.name),
                );
              }).toList(),
            ],
          );
        },
      ),

      // Botón Flotante (SpeedDial) - Se mantiene igual
      floatingActionButton: SpeedDial(
        icon: Icons.add,
        activeIcon: Icons.close,
        backgroundColor: theme.colorScheme.secondary,
        foregroundColor: theme.colorScheme.onSecondary,
        overlayOpacity: 0.5,
        spacing: 10,
        spaceBetweenChildren: 8,
        children: [
          SpeedDialChild(
            child: const Icon(Icons.create_new_folder),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            label: 'Crear Nueva Familia',
            onTap: _showCreateFamilyDialog,
          ),
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