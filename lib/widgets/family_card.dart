// lib/widgets/family_card.dart

import 'package:flutter/material.dart';

import '../models/family.dart';
import '../screens/family_qr_screen.dart';
import '../screens/family_settings_screen.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import 'cached_firebase_image.dart';

/// 🔹 Una tarjeta de lista/familia modularizada que maneja la UI y las acciones de deslizamiento.
class FamilyCard extends StatelessWidget {
  final Family family;
  final VoidCallback onFamilyOpened;
  final VoidCallback onFamilyDeleted;

  // 1. CORRECCIÓN: Quitamos 'const' de la inicialización de los campos
  final FirestoreService _db = FirestoreService();
  final StorageService _storage = StorageService();

  // 2. CORRECCIÓN: Quitamos 'const' del constructor
  FamilyCard({
    super.key,
    required this.family,
    required this.onFamilyOpened,
    required this.onFamilyDeleted,
  });

  // --- MÉTODOS DE LA TARJETA ---

  /// Muestra el diálogo de confirmación para eliminar la familia.
  Future<bool> _confirmDismiss(BuildContext context) async {
    final theme = Theme.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("¿Eliminar familia?"),
        content: Text(
            "Se eliminarán **todos los datos** de '${family.name}'. ¿Estás seguro?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(_, false),
            child: const Text("Cancelar"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
            onPressed: () => Navigator.pop(_, true),
            child: const Text("Eliminar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return confirm ?? false;
  }

  /// Maneja las acciones de Dismissible (Configuración o Eliminación).
  Future<bool> _handleDismiss(BuildContext context, DismissDirection direction) async {
    if (direction == DismissDirection.startToEnd) {
      // Deslizar de izquierda a derecha -> Configuración
      if (!context.mounted) return false;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FamilySettingsScreen(
            familyId: family.id,
            currentName: family.name,
          ),
        ),
      );
      // Retorna false para que la tarjeta no se elimine del listado Stream
      return false; 
    }
    
    // Deslizar de derecha a izquierda -> Eliminación
    if (direction == DismissDirection.endToStart) {
      final confirmed = await _confirmDismiss(context);
      
      if (confirmed) {
        // Ejecutar las operaciones de borrado
        await _storage.deleteFamilyImage(family.id);
        await _db.deleteFamily(family.id);
        
        // Ejecutar callback para mostrar SnackBar o actualizar UI
        onFamilyDeleted(); 
      }
      return confirmed;
    }
    return false;
  }

  // --- WIDGET BUILD ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    final colorSeed = family.id.codeUnits.fold(0, (a, b) => a + b);
    final fallbackColor = Colors.primaries[colorSeed % Colors.primaries.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: Key(family.id),
        direction: DismissDirection.horizontal,
        background: Container(
          color: theme.colorScheme.secondaryContainer,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 24),
          child: Icon(Icons.settings,
              color: theme.colorScheme.onSecondaryContainer, size: 28),
        ),
        secondaryBackground: Container(
          color: theme.colorScheme.errorContainer,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: Icon(Icons.delete_forever,
              color: theme.colorScheme.onErrorContainer, size: 28),
        ),
        confirmDismiss: (direction) => _handleDismiss(context, direction),
        
        // El hijo es la tarjeta de presentación
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onFamilyOpened, // Usamos el callback
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: FutureBuilder<String?>(
                // Reutilizamos la lógica del servicio para la URL
                future: _db.getFamilyImage(family.id), 
                builder: (context, snap) {
                  final imageUrl = snap.data;
                  
                  return ListTile(
                    leading: GestureDetector(
                      onTap: () {
                        if (!context.mounted) return;
                        // Navegación a settings al tocar la imagen/avatar
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
                          ? SizedBox(
                              width: 48, 
                              height: 48,
                              child: ClipOval(
                                child: CachedFirebaseImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover, // Asegura que la imagen cubra el óvalo
                                ),
                              ),
                            )
                          : CircleAvatar(
                              radius: 24,
                              backgroundColor: fallbackColor,
                              child: const Icon(Icons.group, color: Colors.white),
                            ),
                    ),
                    title: Text(
                      family.name,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      "Toca para abrir la lista",
                      style: theme.textTheme.bodyMedium,
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.qr_code, color: theme.colorScheme.secondary),
                      onPressed: () {
                        if (!context.mounted) return;
                        // Navegación al QR code
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FamilyQrScreen(familyId: family.id),
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
  }
}