import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:image_picker/image_picker.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:fotolista_gpt/models/shopping_item.dart';
import 'package:fotolista_gpt/services/firestore_service.dart'; 
import 'package:fotolista_gpt/screens/shopping_list/shopping_list_controller.dart';

class EditItemDialog extends StatefulWidget {
  final ShoppingItem item;
  final String familyId;
  final ShoppingListController controller;
  final Function(ShoppingItem) onSave;

  const EditItemDialog({
    super.key,
    required this.item,
    required this.familyId,
    required this.controller,
    required this.onSave,
  });

  // 🆕 Mantenemos el nombre de la clase, pero la lógica de presentación
  // se mueve al método de llamada en la pantalla principal.

  @override
  State<EditItemDialog> createState() => _EditItemDialogState();
}

class _EditItemDialogState extends State<EditItemDialog> {
  late TextEditingController _nameController;
  late TextEditingController _quantityController;
  File? _newImage;
  late String _selectedCategory; 
  final FirestoreService _firestoreService = FirestoreService(); 

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _quantityController =
        TextEditingController(text: widget.item.quantity.toString()); 
    _selectedCategory = widget.item.category;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() {
        _newImage = File(picked.path);
      });
    }
  }

  Future<void> _save() async {
    String? imageUrl = widget.item.imageUrl;

    if (_newImage != null) {
      imageUrl =
          await widget.controller.uploadImage(_newImage!, widget.familyId);

      if (widget.item.imageUrl != null) {
        await DefaultCacheManager().removeFile(widget.item.imageUrl!);
      }
    }
    
    final int newQuantity = int.tryParse(_quantityController.text) ?? widget.item.quantity;

    final updated = widget.item.copyWith(
      name: _nameController.text.trim().isEmpty
          ? null
          : _nameController.text.trim(),
      imageUrl: imageUrl,
      quantity: newQuantity,
      category: _selectedCategory,
    );

    await widget.controller.updateItem(widget.familyId, updated);
    widget.onSave(updated);

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 🟢 Relleno inferior para adaptarse al teclado
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        // 🆕 Contenedor para la apariencia del ModalBottomSheet
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 🏷️ Encabezado Estilizado
              Text(
                "Editar ${widget.item.name}",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Divider(height: 30),
              
              // 📝 Campo Nombre
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Nombre del Producto",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.shopping_bag_outlined),
                ),
              ),
              const SizedBox(height: 16),
              
              // 🔢 Campo Cantidad
              TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Cantidad",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.numbers),
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly], 
              ),
              const SizedBox(height: 16),

              // 🏷️ Campo Categoría (Dropdown)
              StreamBuilder<List<String>>(
                stream: _firestoreService.getCategories(widget.familyId),
                builder: (context, snapshot) {
                  final categories = snapshot.data ?? ['General'];
                  
                  if (!categories.contains(_selectedCategory)) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                          setState(() {
                              _selectedCategory = 'General';
                          });
                      }
                    });
                  }
                  
                  return InputDecorator(
                    decoration: const InputDecoration(
                      labelText: "Categoría",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: categories.contains(_selectedCategory) ? _selectedCategory : 'General',
                        items: categories.map((String category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedCategory = newValue;
                            });
                          }
                        },
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),
              
              // --- SECCIÓN DE IMAGEN Y BOTÓN ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 🖼️ Vista previa de la imagen
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: _newImage != null
                          ? Image.file(_newImage!, fit: BoxFit.cover)
                          : (widget.item.imageUrl != null
                              ? FutureBuilder<File?>(
                                  future: DefaultCacheManager()
                                      .getSingleFile(widget.item.imageUrl!),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData && snapshot.data != null) {
                                      return Image.file(snapshot.data!, fit: BoxFit.cover);
                                    }
                                    return Icon(Icons.image_not_supported, size: 30, color: Colors.grey.shade400);
                                  },
                                )
                              : Icon(Icons.photo, size: 30, color: Colors.grey.shade400)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // 📷 Botón Cambiar Foto
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo_camera),
                      label: const Text("Cambiar foto"),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 30),
              
              // 💾 Botones de Acción
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("CANCELAR"),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _save,
                    child: const Text("GUARDAR CAMBIOS"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}