import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'package:fotolista_gpt/models/shopping_item.dart';
import 'package:fotolista_gpt/screens/shopping_list/shopping_list_controller.dart';
import 'package:fotolista_gpt/screens/shopping_list/widgets/edit_item_dialog.dart';

class ProductDetailScreen extends StatefulWidget {
  final ShoppingItem item;
  final String familyId;
  final ShoppingListController controller;

  const ProductDetailScreen({
    super.key,
    required this.item,
    required this.familyId,
    required this.controller,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  // 🟢 Guardamos el ítem localmente para poder mutarlo (actualizarlo) después de la edición
  late ShoppingItem _currentItem;
  double _scale = 1.0;
  final TransformationController _transformationController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item; // Inicializar con el ítem pasado
  }

  // 🔄 FUNCIÓN ACTUALIZADA: Usa showModalBottomSheet para una apariencia moderna
  Future<void> _editItem(BuildContext context) async {
    // 1. Mostrar el diálogo de edición como un Bottom Sheet
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Crucial para que el teclado no tape los campos
      builder: (_) => EditItemDialog(
        item: _currentItem, // Pasamos el ítem actual
        familyId: widget.familyId,
        controller: widget.controller,
        onSave: (updatedItem) async {
          // 2. Actualizar el estado local con el nuevo ítem guardado
          setState(() {
            _currentItem = updatedItem;
          });
        },
      ),
    );
  }

  void _handleDoubleTap() {
    final double newScale = _scale == 1.0 ? 2.5 : 1.0;
    setState(() => _scale = newScale);

    // Ajustamos el TransformationController para aplicar el cambio de escala
    final matrix = Matrix4.identity()..scale(newScale);
    _transformationController.value = matrix;
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _currentItem.imageUrl != null;

    return Scaffold(
      // 🟢 Usamos _currentItem.name para reflejar los cambios en el AppBar
      appBar: AppBar(title: Text(_currentItem.name)),
      body: Column(
        children: [
          // --- 🖼️ VISOR DE IMAGEN CON ZOOM (70% del espacio) ---
          Expanded(
            flex: 7, 
            child: Hero(
              tag: "item-${_currentItem.id}",
              child: hasImage
                  ? FutureBuilder<File?>(
                      future: DefaultCacheManager()
                          .getSingleFile(_currentItem.imageUrl!),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        if (snapshot.hasData && snapshot.data != null) {
                          return GestureDetector(
                            onDoubleTap: _handleDoubleTap,
                            child: InteractiveViewer(
                              transformationController:
                                  _transformationController,
                              panEnabled: true,
                              minScale: 1.0,
                              maxScale: 4.0,
                              child: Image.file(
                                snapshot.data!,
                                fit: BoxFit.contain,
                              ),
                            ),
                          );
                        }

                        return const _ImageFallback();
                      },
                    )
                  : const _ImageFallback(),
            ),
          ),
          
          // --- 📝 DETALLES Y ACCIONES (30% del espacio) ---
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 🟢 Mostrar el nombre, ya que el AppBar desaparece al hacer scroll
                  Text(
                    _currentItem.name,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),

                  // 🟢 Detalles del Producto (Categoría, Cantidad, Añadido por)
                  _buildDetailRow(
                    context, 
                    icon: Icons.label_outline, 
                    label: "Categoría", 
                    value: _currentItem.category,
                  ),
                  _buildDetailRow(
                    context, 
                    icon: Icons.numbers, 
                    label: "Cantidad", 
                    value: _currentItem.quantity.toString(),
                  ),
                  _buildDetailRow(
                    context, 
                    icon: Icons.person_outline, 
                    label: "Añadido por", 
                    value: _currentItem.addedByName ?? "Desconocido",
                  ),
                  const Spacer(), // Empuja el botón al final

                  // ✏️ Botón de Edición
                  FilledButton.icon(
                    onPressed: () => _editItem(context),
                    icon: const Icon(Icons.edit),
                    label: const Text("Editar Producto Completo"),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // 🟢 Widget auxiliar para mostrar detalles en una fila
  Widget _buildDetailRow(BuildContext context, {required IconData icon, required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            "$label: ",
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.photo, size: 80, color: Colors.grey),
          SizedBox(height: 12),
          Text("Este producto no tiene imagen",
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}