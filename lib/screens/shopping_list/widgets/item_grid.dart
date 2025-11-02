import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Necesario para FilteringTextInputFormatter
import 'package:intl/intl.dart';

import 'package:fotolista_gpt/models/shopping_item.dart';
import 'package:fotolista_gpt/screens/product_detail_screen.dart';
import 'package:fotolista_gpt/screens/shopping_list/shopping_list_controller.dart';
import 'package:fotolista_gpt/widgets/cached_firebase_image.dart';
// Eliminamos la importación de 'edit_item_dialog.dart' ya que ya no se usa aquí.
// import 'edit_item_dialog.dart'; 

class ItemGrid extends StatelessWidget {
  final ShoppingItem item;
  final String familyId;
  final ShoppingListController controller;
  final int columns;
  final bool isHistory;

  const ItemGrid({
    super.key,
    required this.item,
    required this.familyId,
    required this.controller,
    required this.columns,
    this.isHistory = false,
  });

  Future<bool> _confirmDelete(BuildContext context,
      {bool fromHistory = false}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar producto"),
        content: Text(
          fromHistory
              ? "¿Seguro que quieres eliminar este producto del histórico?"
              : "¿Seguro que quieres eliminar este producto?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  // FUNCIÓN DE EDICIÓN DE CANTIDAD
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

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    
    // 👇 bgStart (Acción de Deslizar a la Derecha)
    final bgStart = Container(
      color: isHistory ? Colors.green : Colors.blue, 
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Icon(isHistory ? Icons.add_shopping_cart : Icons.check, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            isHistory ? 'Añadir a lista' : 'Comprado',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );

    // 👇 bgEnd (Acción de Deslizar a la Izquierda)
    final bgEnd = Container(
      color: Colors.red,
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
    );

    final backgroundColor = isHistory ? Colors.grey.shade300 : Colors.white;
    // Usamos el color secundario para la burbuja de cantidad (como acordamos antes)
    final quantityColor = isHistory 
        ? Colors.grey.shade600 
        : Theme.of(context).colorScheme.secondary;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Dismissible(
        key: Key("grid-${item.id}"),
        background: bgStart,
        secondaryBackground: bgEnd,
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            await controller.toggleBought(familyId, item);
            return false;
          } else {
            final ok = await _confirmDelete(context, fromHistory: isHistory);
            if (ok) {
              await controller.deleteItem(familyId, item);
              return true;
            }
            return false;
          }
        },
        child: GestureDetector(
          onTap: () {
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
          child: Card(
            clipBehavior: Clip.hardEdge,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: backgroundColor,
            child: Stack(
              children: [
                // 1. IMAGEN DE FONDO
                Positioned.fill(
                  child: item.imageUrl != null
                      ? Hero(
                          tag: "item-${item.id}",
                          child: CachedFirebaseImage(
                            imageUrl: item.imageUrl!,
                            isCircle: false,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        )
                      : Container(
                          color: Colors.grey.shade300,
                          child: const Center(
                            child: Icon(Icons.shopping_cart,
                                size: 40, color: Colors.grey),
                          ),
                        ),
                ),
                
                // 2. TEXTO INFERIOR (Solo para Grid de 2 columnas)
                if (columns == 2) // 🟢 Se muestra solo en 2 columnas
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration:
                          BoxDecoration(color: Colors.black.withAlpha(153)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 🟢 Nombre del producto
                          Text(
                            item.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // 🟢 Categoría y Fecha
                          Text(
                            "${item.category} | ${_formatDate(item.createdAt)}",
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // ❌ Eliminamos el botón de edición (Posición 3)

                // 3. BURBUJA DE CANTIDAD (Visible en ambos grids)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _showEditQuantityDialog(context),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: quantityColor,
                        // Sombra para que destaque sobre el fondo
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(76),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                      width: 28, 
                      height: 28,
                      alignment: Alignment.center,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}