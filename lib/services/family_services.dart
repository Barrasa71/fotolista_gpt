import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/family.dart';

// Constante para el nombre de la colección, mejora la legibilidad y previene errores tipográficos.
const String _familiesCollection = 'families';

class FamilyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance; // Usar 'final' y un nombre más descriptivo

  // 💡 Método auxiliar para obtener el ID de usuario de forma segura.
  String? get currentUserId => _auth.currentUser?.uid;

  // 🔹 Crear familia nueva
  /// Crea una nueva familia en Firestore y añade al usuario actual como miembro.
  Future<String> createFamily(String name) async {
    // 💡 Seguridad: Verifica que el usuario está logeado.
    final userId = currentUserId;
    if (userId == null) {
      throw StateError('El usuario no está autenticado.');
    }

    final doc = await _db.collection(_familiesCollection).add({
      'name': name,
      'members': [userId],
      'photoUrl': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id; // Devuelve el ID de la familia recién creada.
  }

  // 🔹 Unirse a familia existente
  /// Añade el usuario actual al array 'members' de la familia especificada.
  Future<void> joinFamily(String familyId) async {
    final userId = currentUserId;
    if (userId == null) {
      throw StateError('El usuario no está autenticado.');
    }

    final familyRef = _db.collection(_familiesCollection).doc(familyId);
    
    // 💡 Robustez: Usa 'FieldValue.arrayUnion' para evitar duplicados.
    await familyRef.update({
      'members': FieldValue.arrayUnion([userId]),
    });
  }

  // 🔹 Salir de familia
  /// Elimina el usuario actual del array 'members' de la familia.
  Future<void> leaveFamily(String familyId) async {
    final userId = currentUserId;
    if (userId == null) {
      throw StateError('El usuario no está autenticado.');
    }
    
    final familyRef = _db.collection(_familiesCollection).doc(familyId);

    // 💡 Manejo de errores: Si el usuario es el último miembro, puede que debas eliminar la familia.
    // Esto es lógica adicional que podrías implementar en el futuro.
    await familyRef.update({
      'members': FieldValue.arrayRemove([userId]),
    });
  }

  // 🔹 Obtener familias donde está el usuario (Stream)
  /// Devuelve un stream de la lista de objetos Family a los que pertenece el usuario.
  Stream<List<Family>> getUserFamilies() {
    final userId = currentUserId;
    if (userId == null) {
      // 💡 Seguridad: Si no hay usuario, devuelve un stream vacío de inmediato.
      return Stream.value([]);
    }

    return _db
        .collection(_familiesCollection)
        .where('members', arrayContains: userId)
        .snapshots()
        // 💡 Mapeo: Transforma el Stream<QuerySnapshot> a Stream<List<Family>>
        .map((snapshot) =>
            snapshot.docs.map((doc) => Family.fromDoc(doc)).toList());
  }

  // 🔹 Obtener una familia por ID (una sola vez)
  /// Obtiene un objeto Family una única vez.
  Future<Family?> getFamilyById(String familyId) async {
    final doc = await _db.collection(_familiesCollection).doc(familyId).get();
    
    if (!doc.exists) return null;
    
    return Family.fromDoc(doc);
  }

  // 🔹 Obtener stream en tiempo real de una familia (Objeto Family)
  /// Devuelve un stream del objeto Family específico.
  Stream<Family?> getFamilyStream(String familyId) {
    return _db
        .collection(_familiesCollection)
        .doc(familyId)
        .snapshots()
        // 💡 Mapeo: Transforma el Stream<DocumentSnapshot> a Stream<Family?>
        .map((docSnapshot) {
          if (docSnapshot.exists) {
            return Family.fromDoc(docSnapshot);
          }
          return null; // Devuelve null si el documento es eliminado o no existe.
        });
  }

  // 🔹 Actualizar nombre de familia
  Future<void> updateFamilyName(String familyId, String name) async {
    await _db.collection(_familiesCollection).doc(familyId).update({'name': name});
  }

  // 🔹 Actualizar foto de familia
  Future<void> setFamilyPhotoUrl(String familyId, String? url) async {
    // 💡 Nota: El campo 'photoUrl' no está en tu modelo Family, pero está bien tenerlo aquí
    // si lo necesitas para fines de UI. Firestore lo almacenará como un campo adicional.
    await _db.collection(_familiesCollection).doc(familyId).update({'photoUrl': url});
  }
}