/*
import 'package:cloud_firestore/cloud_firestore.dart';

class MigrationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> migrateItems() async {
    final families = await _db.collection('families').get();

    for (var family in families.docs) {
      final familyId = family.id;
      final itemsRef = _db.collection('families').doc(familyId).collection('items');
      final items = await itemsRef.get();

      for (var doc in items.docs) {
        final data = doc.data();
        final updates = <String, dynamic>{};

        // Si no tiene 'bought', añadimos false
        if (!data.containsKey('bought')) {
          updates['bought'] = false;
        }

        // Si no tiene 'createdAt', añadimos Timestamp.now()
        if (!data.containsKey('createdAt')) {
          updates['createdAt'] = FieldValue.serverTimestamp();
        }

        if (updates.isNotEmpty) {
          await doc.reference.update(updates);
          print("✅ Migrado item ${doc.id} en familia $familyId");
        }
      }
    }

    print("🎉 Migración completada");
  }
}
*/