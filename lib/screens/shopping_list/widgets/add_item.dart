import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fotolista_gpt/screens/shopping_list/ocr_helper.dart';
import 'package:image_picker/image_picker.dart';
// 🆕 Importamos el servicio de Firestore para obtener las categorías
import '../../../services/firestore_service.dart'; 
// ⚠️ Nota: Asegúrate de que la ruta de importación sea correcta en tu proyecto
// Si no lo es, cámbiala a la ruta correcta de 'firestore_service.dart'

class AddItem extends StatefulWidget {
  final TextEditingController controller;
  // 🔄 CAMBIO 1: La función onAdd ahora requiere la categoría (String)
  final Function(File? imageFile, String? text, String category) onAdd; 

  const AddItem({
    super.key,
    required this.controller,
    required this.onAdd,
  });

  @override
  State<AddItem> createState() => _AddItemState();
}

class _AddItemState extends State<AddItem> {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  final FirestoreService _firestoreService = FirestoreService(); // 🆕 Instancia del servicio
  
  // 🆕 Estado para la categoría seleccionada
  String _selectedCategory = 'General'; 
  
  // ⚠️ TEMPORAL: Necesitas el ID de la familia para obtener las categorías
  // ASUNCION: Asumimos un Family ID de prueba temporal. 
  // La pantalla padre (shopping_item_screen.dart) debe proveer el ID real.
  // Por ahora, usamos un string vacío o un placeholder.
  // 👉 DEBES re-introducir el ID de la familia real aquí o pasarlo como parámetro
  final String _testFamilyId = 'USFPq66ANI8VMSYoRg'; 


  @override
  void initState() {
    super.initState();
    // 🆕 Inicialmente, establecemos la categoría por defecto
    _selectedCategory = 'General';
  }

  /// 📸 Elegir imagen de galería
  Future<void> _pickImageFromGallery() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      _processImage(File(pickedFile.path));
    }
  }

  /// 📸 Tomar foto con cámara
  Future<void> _pickImageFromCamera() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      imageQuality: 70,
    );
    if (pickedFile != null) {
      _processImage(File(pickedFile.path));
    }
  }

  /// 🧠 Procesar imagen con OCR
  Future<void> _processImage(File image) async {
    setState(() => _selectedImage = image);

    final extractedLines = await OcrHelper.extractTextFromImage(image);
    if (extractedLines.isEmpty) return;
    if (!mounted) return;

    final selectedText =
        await OcrHelper.showTextSuggestionsDialog(context, extractedLines);

    if (selectedText != null && selectedText.trim().isNotEmpty) {
      widget.controller.text = selectedText.trim();
    }
  }

  void _addItem() {
    final trimmedText = widget.controller.text.trim();
    if (trimmedText.isEmpty) return;

    // 🔄 CAMBIO 2: Pasamos la categoría seleccionada a la función onAdd
    widget.onAdd(_selectedImage, trimmedText, _selectedCategory); 
    
    // Reseteamos el estado local después de añadir
    setState(() {
      _selectedImage = null;
      _selectedCategory = 'General'; // Volver a la categoría por defecto
    });
    widget.controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column( // 🆕 CAMBIO: Usamos una columna para organizar el selector y la fila de texto
        mainAxisSize: MainAxisSize.min,
        children: [
          // 🆕 Selector de Categoría (en una fila separada)
          StreamBuilder<List<String>>(
            // ⚠️ ASUNCIÓN: Usamos el ID de prueba. Reemplazar con el ID de la familia real.
            stream: _firestoreService.getCategories(_testFamilyId), 
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }
              
              // Si no hay datos, mostramos solo 'General'
              final categories = snapshot.data ?? ['General']; 
              
              // Aseguramos que la categoría seleccionada esté en la lista actual
              if (!categories.contains(_selectedCategory)) {
                  // Esto podría pasar si se borró una categoría. Volvemos a 'General'
                  _selectedCategory = 'General'; 
              }

              return Row(
                children: [
                  const Text('Categoría:'),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedCategory,
                      items: categories.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
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
                ],
              );
            },
          ),
          
          // Fila original para texto, imagen y botones de cámara/galería
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.photo),
                tooltip: "Elegir de galería",
                onPressed: _pickImageFromGallery,
              ),
              IconButton(
                icon: const Icon(Icons.camera_alt),
                tooltip: "Tomar foto",
                onPressed: _pickImageFromCamera,
              ),
              if (_selectedImage != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Image.file(
                    _selectedImage!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                ),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  decoration: const InputDecoration(
                    labelText: "Añadir producto",
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _addItem(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _addItem,
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(16),
                ),
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
    );
  }
}