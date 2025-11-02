import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/shopping_item.dart';

// Constantes para los nombres de colecciones
const String _familiesCollection = 'families';
const String _itemsCollection = 'items';
const String _usersCollection = 'users';

// Este servicio gestiona todas las operaciones relacionadas con los artículos de la compra.
class ShoppingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 💡 Método auxiliar para obtener el ID de usuario de forma segura.
  String? get currentUserId => _auth.currentUser?.uid;

  /// 🔹 Añade un producto a la lista de la familia.
  Future<void> addProduct({
    required String familyId,
    required String name,
    int quantity = 1,
    String category = 'General',
    String? imageUrl, // 💡 Añadimos la URL de la imagen opcional
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      throw StateError('El usuario no está autenticado. No se puede añadir el producto.');
    }

    // 1. Obtener el nombre del usuario que añade el producto (Mejora de Robustez)
    String addedByName = 'Alguien';
    try {
      // 💡 Mejor práctica: Asumimos que el nombre completo está en la colección de 'users'
      // Si tu diseño usa 'members' dentro de 'families', mantendremos esa lógica, pero aquí
      // asumimos que el perfil de usuario es la fuente principal para su nombre.
      final userDoc = await _db.collection(_usersCollection).doc(userId).get();
      addedByName = (userDoc.data()?['fullName'] as String?) ?? 'Miembro Desconocido';
    } catch (e) {
      // Manejar errores de lectura de Firestore.
      print('Error al obtener el nombre del usuario: $e');
    }

    // 2. Creamos una instancia completa del modelo ShoppingItem
    // Nota: El ID del item será el ID del documento generado por Firestore.
    final newItemData = ShoppingItem(
      id: '', // Se rellenará al crear el documento.
      name: name,
      quantity: quantity,
      bought: false,
      createdAt: DateTime.now(),
      addedBy: userId,
      addedByName: addedByName,
      category: category,
      imageUrl: imageUrl, // Incluir la URL
    ).toJson(); // Convertimos el objeto a un Map para Firestore

    // 3. Añadimos el item a la subcolección 'items' de la familia.
    // Usamos el camino completo: families/{familyId}/items/{itemId}
    await _db
        .collection(_familiesCollection)
        .doc(familyId)
        .collection(_itemsCollection)
        .add(newItemData);

    print('✅ Producto "$name" (Categoría: $category) añadido por $addedByName');
  }

  /// 🔹 Obtener stream de artículos para una familia (Lista en tiempo real)
  /// Devuelve un Stream<List<ShoppingItem>> con todos los artículos de la lista.
  Stream<List<ShoppingItem>> getShoppingListStream(String familyId) {
    return _db
        .collection(_familiesCollection)
        .doc(familyId)
        .collection(_itemsCollection)
        .orderBy('createdAt', descending: true) // Ordenar por fecha de creación
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ShoppingItem.fromFirestore(doc))
            .toList());
  }

  /// 🔹 Actualizar el estado de "comprado" de un artículo
  Future<void> toggleBoughtStatus({
    required String familyId,
    required String itemId,
    required bool isBought,
  }) async {
    await _db
        .collection(_familiesCollection)
        .doc(familyId)
        .collection(_itemsCollection)
        .doc(itemId)
        .update({'bought': isBought});
  }

  /// 🔹 Actualizar la cantidad de un artículo
  Future<void> updateItemQuantity({
    required String familyId,
    required String itemId,
    required int newQuantity,
  }) async {
    await _db
        .collection(_familiesCollection)
        .doc(familyId)
        .collection(_itemsCollection)
        .doc(itemId)
        .update({'quantity': newQuantity});
  }

  /// 🔹 Eliminar un artículo de la lista
  Future<void> deleteItem({
    required String familyId,
    required String itemId,
  }) async {
    await _db
        .collection(_familiesCollection)
        .doc(familyId)
        .collection(_itemsCollection)
        .doc(itemId)
        .delete();
  }
}