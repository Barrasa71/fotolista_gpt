import 'package:cloud_firestore/cloud_firestore.dart';

// Este modelo representa un artículo individual en la lista de la compra.
class ShoppingItem {
  // 💡 Propiedades esenciales (siempre deben tener un valor)
  final String id;
  final String name; 
  final bool bought;
  final DateTime createdAt;
  final int quantity;
  final String category;

  // 💡 Propiedades opcionales (pueden ser nulas)
  final String? imageUrl;
  final String? addedBy;
  final String? addedByName;

  ShoppingItem({
    required this.id,
    required this.name,
    this.imageUrl,
    this.bought = false,
    required this.createdAt,
    this.addedBy,
    this.addedByName,
    this.quantity = 1,
    this.category = 'General',
  });

  /// 🔹 Construir un ShoppingItem desde Firestore
  /// Usa el ID del documento (doc.id) como la fuente principal para el ID del objeto.
  factory ShoppingItem.fromFirestore(DocumentSnapshot doc) {
    // Manejo seguro: si doc.data() es null, usamos un mapa vacío.
    final data = (doc.data() as Map<String, dynamic>?) ?? {};

    // 💡 Mejora: Manejo más limpio del campo 'createdAt' (Timestamp de Firestore a DateTime de Dart)
    final Timestamp? timestamp = data['createdAt'] as Timestamp?;
    final DateTime createdAtDate = timestamp?.toDate() ?? DateTime.now();

    // 💡 Mejora: Manejo del nombre nulo. Si es nulo, usamos un valor por defecto.
    final String itemName = data['name'] as String? ?? 'Producto Desconocido';
    
    // 💡 Nota: Aseguramos que el ID del objeto sea el ID del documento.
    return ShoppingItem(
      id: doc.id,
      name: itemName,
      imageUrl: data['imageUrl'] as String?,
      bought: data['bought'] as bool? ?? false,
      createdAt: createdAtDate,
      addedBy: data['addedBy'] as String?,
      addedByName: data['addedByName'] as String?,
      // Casteo seguro de `num` (int o double) a `int`
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      category: data['category'] as String? ?? 'General',
    );
  }

  /// 🔹 Convertir a JSON (para guardar en Firestore)
  /// Nota: Se omite el 'id' ya que Firestore lo maneja como Document ID.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'imageUrl': imageUrl,
      'bought': bought,
      // Siempre convertimos el DateTime de Dart a Timestamp para Firestore
      'createdAt': Timestamp.fromDate(createdAt),
      'addedBy': addedBy,
      'addedByName': addedByName,
      'quantity': quantity,
      'category': category,
    };
  }

  /// 🔹 Copiar con cambios (útil para actualizaciones)
  ShoppingItem copyWith({
    String? id,
    String? name,
    String? imageUrl,
    bool? bought,
    DateTime? createdAt,
    String? addedBy,
    String? addedByName,
    int? quantity,
    String? category,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      bought: bought ?? this.bought,
      createdAt: createdAt ?? this.createdAt,
      addedBy: addedBy ?? this.addedBy,
      addedByName: addedByName ?? this.addedByName,
      quantity: quantity ?? this.quantity,
      category: category ?? this.category,
    );
  }

  // 👇 Implementación crucial para Clases de Valor (Value Objects)

  /// 🔹 Método para facilitar la depuración
  @override
  String toString() {
    return 'ShoppingItem(id: $id, name: $name, bought: $bought, quantity: $quantity, category: $category)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ShoppingItem &&
        other.id == id &&
        other.name == name &&
        other.imageUrl == imageUrl &&
        other.bought == bought &&
        // Usar isAtSameMomentAs para comparar la fecha, ignorando microsegundos que pueden ser inconsistentes.
        other.createdAt.isAtSameMomentAs(createdAt) && 
        other.addedBy == addedBy &&
        other.addedByName == addedByName &&
        other.quantity == quantity &&
        other.category == category;
  }

  @override
  int get hashCode => Object.hash(
      id,
      name,
      imageUrl,
      bought,
      createdAt,
      addedBy,
      addedByName,
      quantity,
      category);
}