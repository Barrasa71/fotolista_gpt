import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

// Este modelo representa una unidad familiar en tu aplicación.
class Family {
  // 💡 Campo ID: Es fundamental para identificar el documento en Firestore.
  final String id;
  // 💡 Campo Name: Nombre de la familia (ej. "Familia Pérez").
  final String name;
  // 💡 Campo Members: Lista de IDs de usuario que pertenecen a esta familia.
  final List<String> members;

  Family({
    required this.id,
    required this.name,
    required this.members,
  });

  // 🔹 Constructor para Inmutabilidad (copyWith)
  /// Crea una nueva instancia de Family con los campos modificados, manteniendo la inmutabilidad.
  Family copyWith({
    String? id,
    String? name,
    List<String>? members,
  }) {
    return Family(
      id: id ?? this.id,
      name: name ?? this.name,
      members: members ?? this.members,
    );
  }

  /// 🔹 Crear desde snapshot de Firestore
  /// Factory constructor para construir un objeto Family a partir de un DocumentSnapshot de Firestore.
  factory Family.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    
    // Verificación de nulidad y manejo de datos, asegurando que 'data' no es null.
    if (data == null) {
      throw const FormatException("El DocumentSnapshot no contiene datos válidos.");
    }

    return Family(
      id: doc.id,
      name: data['name'] as String? ?? '', // Uso de 'as String?' para tipado seguro
      // Uso de List<String>.from para garantizar que el tipo es List<String>.
      members: List<String>.from(data['members'] as List<dynamic>? ?? []),
    );
  }

  /// 🔹 Convertir a JSON (para guardar en Firestore)
  /// Convierte el objeto Family a un Map<String, dynamic> para su almacenamiento en Firestore.
  Map<String, dynamic> toJson() {
    // Nota: El 'id' se omite porque es el ID del documento en Firestore.
    return {
      'name': name,
      'members': members,
    };
  }

  // 👇 Implementación crucial para Clases de Valor (Value Objects)
  // Permite comparar dos objetos Family por su contenido y no por su referencia en memoria.

  @override
  String toString() {
    return 'Family(id: $id, name: $name, members: $members)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    // Utilizamos 'listEquals' de 'package:flutter/foundation.dart' para una
    // comparación profunda de los contenidos de las listas.
    return other is Family &&
        other.id == id &&
        other.name == name &&
        listEquals(other.members, members); 
  }

  @override
  int get hashCode => Object.hash(id, name, Object.hashAll(members));
}