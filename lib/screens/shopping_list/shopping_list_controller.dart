import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:fotolista_gpt/models/shopping_item.dart';
import 'package:fotolista_gpt/services/cache_service.dart';
import 'package:fotolista_gpt/services/firestore_service.dart';
import 'package:fotolista_gpt/services/storage_service.dart';

class ShoppingListController {
  final FirestoreService _db = FirestoreService();
  final StorageService _storage = StorageService();

  /// ➕ Añadir item nuevo (con soporte de imagen, nombre del autor, cantidad y categoría)
  /// Escribe directamente en families/{familyId}/items para disparar la Cloud Function.
  Future<void> addItem(
    String familyId, {
    File? imageFile,
    String? name,
    int? quantity,
    // 👇 CAMBIO 1: Nuevo parámetro para la categoría
    String? category,
  }) async {
    if ((name == null || name.trim().isEmpty) && imageFile == null) return;

    String? imageUrl;
    if (imageFile != null) {
      imageUrl = await _storage.uploadImage(imageFile, familyId);
    }

    final user = FirebaseAuth.instance.currentUser;
    final addedByUid = user?.uid;
    final addedByName =
        user?.displayName ?? user?.email?.split('@').first ?? 'Alguien';

    final trimmedName =
        (name == null || name.trim().isEmpty) ? null : name.trim();

    final int finalQuantity = quantity ?? 1;
    // 🟢 Asegurar la categoría, si es null, usar 'General'
    final String finalCategory = category ?? 'General';

    // ✅ Guardamos directamente en "items" (no ShoppingItem ni shoppingList)
    final docRef = FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('items')
        .doc(); // 👈 creamos el doc antes de setearlo

    await docRef.set({
      'id': docRef.id,
      'name': trimmedName,
      'imageUrl': imageUrl,
      'bought': false,
      'createdAt': FieldValue.serverTimestamp(),
      'addedBy': addedByUid,
      'addedByName': addedByName,
      'quantity': finalQuantity, 
      // 🟢 Incluir la categoría en Firestore
      'category': finalCategory,
    });
  }

  /// 🔄 Alternar estado comprado/no comprado
  Future<void> toggleBought(String familyId, ShoppingItem item) async {
    // Usamos copyWith para actualizar, que ya incluye 'quantity' y 'category'
    final updated = item.copyWith(
      bought: !item.bought,
    );
    await _db.updateItem(familyId, updated);
  }

  /// 🗑️ Eliminar un item y limpiar cache si tiene imagen
  Future<void> deleteItem(String familyId, ShoppingItem item) async {
    await _db.deleteItem(familyId, item.id);
    if (item.imageUrl != null) {
      await AppCacheManager.instance.removeFile(item.imageUrl!);
    }
  }

  /// ✏️ Actualizar item
  Future<void> updateItem(String familyId, ShoppingItem item) async {
    await _db.updateItem(familyId, item);
  }
  
  // ---------------------------
  // 🆕 MÉTODOS DE GESTIÓN DE CATEGORÍA
  // ---------------------------

  /// 📥 Obtener el Stream de todas las categorías (incluyendo 'General')
  Stream<List<String>> getCategories(String familyId) {
    return _db.getCategories(familyId);
  }

  /// ➕ Añadir una nueva categoría a Firestore
  Future<void> addCategory(String familyId, String categoryName) async {
    await _db.addCategory(familyId, categoryName);
  }
  
  /// 🔄 Mover un item a una nueva categoría
  Future<void> moveItemToCategory(
      String familyId, ShoppingItem item, String newCategory) async {
    // Si la categoría ya es la misma, no hacemos nada
    if (item.category == newCategory) return;
    
    // 🟢 1. Creamos una copia del item con la nueva categoría
    final updatedItem = item.copyWith(category: newCategory);
    
    // 🟢 2. Llamamos al servicio de Firestore para actualizar el documento
    await _db.updateItem(familyId, updatedItem);
    
    print('📦 Item "${item.name}" movido de ${item.category} a $newCategory');
  }

  /// 🗑️ Eliminar una categoría (delegando la lógica de seguridad a FirestoreService)
  Future<void> deleteCategory(String familyId, String categoryName) async {
    await _db.deleteCategory(familyId, categoryName);
  }

  /// 🔎 Contar el número de ítems en una categoría específica
  Future<int> countItemsInCategory(String familyId, String categoryName) async {
    return await _db.countItemsInCategory(familyId, categoryName);
  }
  
  // ---------------------------

  /// 📥 Subir nueva imagen de item
  Future<String?> uploadImage(File file, String familyId) async {
    return await _storage.uploadImage(file, familyId);
  }

  /// 🔎 Obtener items con filtro comprado/no comprado
  Stream<List<ShoppingItem>> getItems(String familyId, {bool? bought}) {
    return _db.getItems(familyId, bought: bought);
  }
}