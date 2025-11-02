import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/services.dart'; 

import 'package:fotolista_gpt/models/shopping_item.dart';
import 'package:fotolista_gpt/screens/product_detail_screen.dart';
import 'package:fotolista_gpt/screens/shopping_list/shopping_list_controller.dart';
// Eliminamos la importación de 'edit_item_dialog.dart' ya que ya no se usa aquí.
// Pero la mantenemos comentada si deseas acceso rápido en el futuro
// import 'edit_item_dialog.dart'; 

class ItemTile extends StatelessWidget {
  final ShoppingItem item;
  final String familyId;
  final ShoppingListController controller;
  final bool isHistory;

  const ItemTile({
    super.key,
    required this.item,
    required this.familyId,
    required this.controller,
    this.isHistory = false,
  });
  
  // Función para mostrar el diálogo de edición de cantidad (se mantiene igual)
  Future<void> _showEditQuantityDialog(BuildContext context) async {
    final quantityController = TextEditingController(text: item.quantity.toString());

    final result = await showDialog<int?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text("Cambiar Cantidad de ${item.name}"),
          content: TextField(
            controller: quantityController,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: "Nueva Cantidad",
              border: OutlineInputBorder(),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text("Cancelar"),
            ),
            FilledButton(
              onPressed: () {
                final newQuantity = int.tryParse(quantityController.text.trim());
                if (newQuantity == null || newQuantity < 1) {
                   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("La cantidad debe ser al menos 1")),
                  );
                  return;
                }
                Navigator.pop(ctx, newQuantity);
              },
              child: const Text("Guardar"),
            ),
          ],
        );
      },
    );

    if (result != null && result != item.quantity) {
      final updatedItem = item.copyWith(quantity: result);
      await controller.updateItem(familyId, updatedItem);
    }
  }

  // ❌ Eliminamos la función _showEditFullDialog ya que es redundante

  @override
  Widget build(BuildContext context) {
    
    final bool shouldBeStriked = item.bought && !isHistory;
    
    final textDecoration = shouldBeStriked ? TextDecoration.lineThrough : null;
    final itemColor = item.bought && !isHistory ? Colors.grey : Colors.black;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        elevation: 3,
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).cardColor,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // 🎯 Al tocar el tile, navegamos a la pantalla de detalle (donde está la edición completa)
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(
                  item: item,
                  familyId: familyId,
                  controller: controller,
                ),
              ),
            );
          },
          child: Dismissible(
            key: Key(item.id),
            direction: DismissDirection.horizontal,
            
            // 👇 ACCIÓN PRIMARIA (Deslizar Derecha: Comprar/Añadir a Lista)
            background: Container(
              decoration: BoxDecoration(
                // Si es Histórico (isHistory=true) -> Verde (Añadir a Lista)
                // Si es Lista Activa (isHistory=false) -> Azul (Comprado)
                color: isHistory ? Colors.green : Colors.blue,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row( // Usamos Row para centrar el icono y el texto
                children: [
                  Icon(isHistory ? Icons.add_shopping_cart : Icons.check, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    isHistory ? 'Añadir a lista' : 'Comprado',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            
            // 👇 ACCIÓN SECUNDARIA (Deslizar Izquierda: Eliminar)
            secondaryBackground: Container(
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Eliminar',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.delete, color: Colors.white),
                ],
              ),
            ),

            confirmDismiss: (direction) async {
              if (direction == DismissDirection.startToEnd) {
                await controller.toggleBought(familyId, item);
                return false;
              } else {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Eliminar producto"),
                    content: Text(
                        "¿Seguro que quieres eliminar este producto${isHistory ? " del histórico" : ""}?"),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text("Cancelar")),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text("Eliminar")),
                    ],
                  ),
                );
                if (ok == true) {
                  await controller.deleteItem(familyId, item);
                  return true;
                }
                return false;
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 🖼️ Imagen / Icono
                  Hero(
                    tag: "item-${item.id}",
                    child: item.imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: FutureBuilder<File?>(
                              future: DefaultCacheManager()
                                  .getSingleFile(item.imageUrl!),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Container(
                                    width: 56,
                                    height: 56,
                                    color: Colors.grey[300],
                                    child: const CircularProgressIndicator(
                                        strokeWidth: 2),
                                  );
                                }
                                if (snapshot.hasData && snapshot.data != null) {
                                  return Image.file(
                                    snapshot.data!,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                  );
                                }
                                return Container(
                                  width: 56,
                                  height: 56,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.photo,
                                      color: Colors.white),
                                );
                              },
                            ),
                          )
                        : Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.teal,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isHistory ? Icons.history : Icons.shopping_cart,
                              color: Colors.white,
                            ),
                          ),
                  ),
                  const SizedBox(width: 16),
                  
                  // 📝 Detalles (Nombre, Categoría y Fecha)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            decoration: textDecoration,
                            color: itemColor,
                          ),
                        ),
                        
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.label_outline, size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              item.category,
                              style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "${item.createdAt.day.toString().padLeft(2, '0')}/"
                              "${item.createdAt.month.toString().padLeft(2, '0')}/"
                              "${item.createdAt.year}",
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // 🔢 BURBUJA DE CANTIDAD (Edición Rápida)
                  GestureDetector(
                    onTap: () => _showEditQuantityDialog(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0), 
                      child: CircleAvatar(
                        radius: 14, 
                        backgroundColor: isHistory 
                          ? Colors.grey 
                          : Theme.of(context).colorScheme.secondary, 
                        child: Text(
                          item.quantity.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // ❌ ELIMINAMOS EL BOTÓN DE EDICIÓN COMPLETA
                  // Ya que se accede pulsando en la foto
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}