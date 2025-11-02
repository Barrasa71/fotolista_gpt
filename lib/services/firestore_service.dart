import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/shopping_item.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------------------------
  // Familias
  // ---------------------------

  /// 🔹 Crear una nueva familia con el usuario actual como miembro
  Future<void> createFamily(String name) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    await _db.collection('families').add({
      'name': name,
      'members': [userId],
    });
  }

  /// 🔹 Obtener la URL de la foto de la familia (una vez)
  Future<String?> getFamilyImage(String familyId) async {
    final doc = await _db.collection('families').doc(familyId).get();
    if (!doc.exists) return null;
    final data = doc.data();
    return data?['photoUrl'] as String?;
  }

  /// 🔹 Actualizar la URL de la foto de la familia
  Future<void> updateFamilyImage(String familyId, String? url) async {
    await _db.collection('families').doc(familyId).update({'photoUrl': url});
  }

  /// 🔹 Actualizar el nombre de la familia
  Future<void> updateFamilyName(String familyId, String name) async {
    await _db.collection('families').doc(familyId).update({'name': name});
  }

  // ---------------------------
  // Items de compra
  // ---------------------------

  /// 🔹 Añadir un item nuevo a la lista de compra
  Future<void> addItem(String familyId, ShoppingItem item) async {
    final col = _db.collection('families').doc(familyId).collection('items');
    final docRef = col.doc();

    await docRef.set({
      'id': docRef.id,
      'name': item.name,
      'imageUrl': item.imageUrl,
      'bought': item.bought,
      'createdAt': Timestamp.fromDate(item.createdAt),
      'addedBy': item.addedBy,
      'addedByName': item.addedByName,
      'quantity': item.quantity,
      // 👇 CAMBIO: Incluir la categoría en el set
      'category': item.category, 
    });
  }

  /// 🔹 Actualizar un item existente
  Future<void> updateItem(String familyId, ShoppingItem item) async {
    await _db
        .collection('families')
        .doc(familyId)
        .collection('items')
        .doc(item.id)
        .update({
      'name': item.name,
      'imageUrl': item.imageUrl,
      'bought': item.bought,
      'quantity': item.quantity, 
      // 👇 CAMBIO: Incluir la categoría para la actualización
      'category': item.category, 
    });
  }

  /// 🔹 Eliminar item y su imagen del storage
  Future<void> deleteItem(String familyId, String itemId) async {
    final itemRef =
        _db.collection('families').doc(familyId).collection('items').doc(itemId);

    final itemSnapshot = await itemRef.get();
    if (itemSnapshot.exists) {
      final data = itemSnapshot.data() as Map<String, dynamic>;
      final imageUrl = data['imageUrl'] as String?;

      if (imageUrl != null && imageUrl.contains('/items/')) {
        final fileName = imageUrl.split('/').last.split('?').first;
        try {
          await FirebaseStorage.instance
              .ref()
              .child('families/$familyId/items/$fileName')
              .delete();
        } catch (_) {
          // Ignorar si no existe
        }
      }
    }

    await itemRef.delete();
  }

  /// 🔹 Eliminar una familia completa y su contenido
  Future<void> deleteFamily(String familyId) async {
    final familyRef = _db.collection('families').doc(familyId);
    final itemsRef = familyRef.collection('items');

    final itemsSnapshot = await itemsRef.get();
    for (final doc in itemsSnapshot.docs) {
      final data = doc.data();
      final imageUrl = data['imageUrl'] as String?;
      if (imageUrl != null && imageUrl.contains('/items/')) {
        final fileName = imageUrl.split('/').last.split('?').first;
        try {
          await FirebaseStorage.instance
              .ref()
              .child('families/$familyId/items/$fileName')
              .delete();
        } catch (_) {
          // Ignorar si no existe
        }
      }
      await doc.reference.delete();
    }

    try {
      await FirebaseStorage.instance
          .ref()
          .child('families/$familyId/family_photo.jpg')
          .delete();
    } catch (_) {}

    await familyRef.delete();
  }

  /// 🔎 Obtener items (sin índice compuesto) + logs de depuración
  Stream<List<ShoppingItem>> getItems(String familyId, {bool? bought}) {
    Query<Map<String, dynamic>> query =
        _db.collection('families').doc(familyId).collection('items');

    if (bought != null) {
      query = query.where('bought', isEqualTo: bought);
    }

    return query.snapshots().map((snapshot) {
      final items = snapshot.docs.map((doc) {
        try {
          return ShoppingItem.fromFirestore(doc);
        } catch (e) {
          print('⚠️ Error parseando item ${doc.id}: $e');
          return null;
        }
      }).whereType<ShoppingItem>().toList();

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      print(
          '📡 getItems("$familyId", bought: $bought) -> ${items.length} items');
      return items;
    });
  }
  
  // ---------------------------
  // 🆕 GESTIÓN DE CATEGORÍAS
  // ---------------------------
  
  /// 🔹 Obtener el Stream de categorías definidas por el usuario (más 'General')
  Stream<List<String>> getCategories(String familyId) {
    return _db
        .collection('families')
        .doc(familyId)
        .collection('categories') // Colección de categorías personalizadas
        .snapshots()
        .map((snapshot) {
      // Mapeamos los documentos a una lista de nombres de categoría (usamos el doc.id como nombre)
      final customCategories = snapshot.docs.map((doc) => doc.id).toList();
      
      // La lista siempre empieza con "General" y luego las personalizadas
      return ['General', ...customCategories];
    });
  }

  /// 🔹 Añadir una nueva categoría a la familia
  Future<void> addCategory(String familyId, String categoryName) async {
    final trimmedName = categoryName.trim();
    if (trimmedName.isEmpty || trimmedName.toLowerCase() == 'general') return;

    await _db
        .collection('families')
        .doc(familyId)
        .collection('categories')
        // Usamos el nombre de la categoría como ID del documento para que sea único
        .doc(trimmedName) 
        .set({}); 
  }
  
  /// 🔹 Eliminar una categoría de forma segura (reasignando items)
  Future<void> deleteCategory(String familyId, String categoryName) async {
    if (categoryName.toLowerCase() == 'general') {
      print('❌ No se puede eliminar la categoría "General"');
      return;
    }
    
    final categoryRef = _db
        .collection('families')
        .doc(familyId)
        .collection('categories')
        .doc(categoryName);
    
    // 1. 🔍 Encontrar todos los artículos que pertenecen a esta categoría
    final itemsToReassign = await _db
        .collection('families')
        .doc(familyId)
        .collection('items')
        .where('category', isEqualTo: categoryName)
        .get();
        
    // 2. 📝 Crear un lote de escritura para actualizar y borrar
    final batch = _db.batch();
    
    // 3. 🔄 Reasignar los artículos a 'General'
    for (final doc in itemsToReassign.docs) {
      batch.update(doc.reference, {'category': 'General'});
    }
    
    // 4. 🗑️ Añadir la eliminación de la categoría al lote
    batch.delete(categoryRef);
    
    // 5. 🚀 Ejecutar el lote (las actualizaciones y la eliminación ocurrirán juntas)
    await batch.commit();

    print('✅ Categoría "$categoryName" eliminada y ${itemsToReassign.size} items reasignados a "General".');
  }
  
  /// 🔎 Método para obtener la cuenta de ítems por categoría
  // 🟢 CORRECCIÓN: Acceder a .count y asegurar que el tipo de retorno sea int
  Future<int> countItemsInCategory(String familyId, String categoryName) async {
     final snapshot = await _db
        .collection('families')
        .doc(familyId)
        .collection('items')
        .where('category', isEqualTo: categoryName)
        .count()
        .get();
     // Retornamos el valor de count, asegurando que sea 0 si es nulo (seguridad)
     return snapshot.count?.toInt() ?? 0;
  }

}