// lib/screens/shopping_list/shopping_item_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:fotolista_gpt/screens/auth_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

import 'package:fotolista_gpt/models/shopping_item.dart';
import 'package:fotolista_gpt/screens/shopping_list/widgets/item_tile.dart';
import 'package:fotolista_gpt/screens/shopping_list/widgets/item_grid.dart';
import 'package:fotolista_gpt/screens/shopping_list/shopping_list_controller.dart';
import 'package:fotolista_gpt/screens/shopping_list/ocr_helper.dart';

// 🟢 Importaciones necesarias para la configuración de fuente
import 'package:fotolista_gpt/main.dart'; // Para acceder a MyApp
import 'package:fotolista_gpt/screens/font_scale_setting_dialog.dart'; // Para el diálogo

class ShoppingItemScreen extends StatefulWidget {
  final String familyId;

  const ShoppingItemScreen({super.key, required this.familyId});

  @override
  State<ShoppingItemScreen> createState() => _ShoppingItemScreenState();
}

class _ShoppingItemScreenState extends State<ShoppingItemScreen> {
  final ShoppingListController _controller = ShoppingListController();
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  int _selectedView = 0;
  String _query = "";

  /// 🎙️ Speech-to-text
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _voiceText = "";

  final TextEditingController _newCategoryController = TextEditingController();

  // ESTADO: Controla si estamos en modo de movimiento de categoría (LongPress)
  bool _isCategoryMoveMode = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  /// Añadir producto (imagen + texto + cantidad + CATEGORÍA)
  Future<void> _addItem(
    String familyId, {
    File? imageFile,
    String? name,
    int? quantity,
    String? category,
  }) async {
    // 1. Aseguramos el nombre de la categoría
    final String finalCategory = category ?? 'General';

    // 2. LÓGICA DE CREACIÓN BAJO DEMANDA
    if (finalCategory.toLowerCase() != 'general') {
        final categoryDoc = await FirebaseFirestore.instance
            .collection('families')
            .doc(familyId)
            .collection('categories')
            .doc(finalCategory)
            .get();

        // Si la categoría NO existe, la creamos
        if (!categoryDoc.exists) {
            await _controller.addCategory(familyId, finalCategory);
            print("✅ Categoría '$finalCategory' creada bajo demanda.");
        }
    }
    // ----------------------------------------------------------------------


    // 3. Llamamos al controlador para añadir el ítem
    await _controller.addItem(
      familyId,
      imageFile: imageFile,
      name: name,
      quantity: quantity,
      category: finalCategory,
    );
    print(
        "🆕 Producto añadido localmente: $name (x${quantity ?? 1}) en $finalCategory");
  }

  Future<void> _addFromCamera() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      imageQuality: 70,
    );
    if (pickedFile == null) return;

    final imageFile = File(pickedFile.path);
    await _processImage(imageFile);
  }

  Future<void> _addFromGallery() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final imageFile = File(pickedFile.path);
    await _processImage(imageFile);
  }

  // --- Diálogo de confirmación de Nombre, Cantidad y Categoría ---
  Future<Map<String, dynamic>?> _showNameAndQuantityDialog({
    String? initialName,
    File? imageFile,
    bool isManual = false,
    String initialCategory = 'General', // 🆕 Nueva categoría inicial
    int initialQuantity = 1, // 🆕 Nueva cantidad inicial
  }) async {
    final nameController = TextEditingController(text: initialName ?? "");
    final quantityController = TextEditingController(text: initialQuantity.toString()); 

    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        // 1. Envolvemos el contenido en un StreamBuilder para las categorías
        return StreamBuilder<List<String>>(
          stream: _controller.getCategories(widget.familyId),
          builder: (context, snapshot) {
            
            final existingCategories = snapshot.data ?? ['General']; 
            String selectedCategory = initialCategory; 
            List<String> displayCategories = [...existingCategories];

            // Si la categoría sugerida no existe, la añadimos a la lista local para que se preseleccione
            if (!existingCategories.contains(initialCategory)) {
                displayCategories.add(initialCategory);
            }
            
            // Si el valor inicial está en la lista de opciones (existente o temporalmente añadido)
            if (!displayCategories.contains(initialCategory)) {
                selectedCategory = 'General';
            } else {
                selectedCategory = initialCategory;
            }


            // El contenido debe ser reconstruido si las categorías cambian
            return StatefulBuilder(builder: (context, setStateDialog) {
              return AlertDialog(
                title: Text(isManual
                    ? "Añadir Productos (Línea a Línea)"
                    : "Confirmar Producto y Cantidad"),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Vista previa de la imagen
                      if (imageFile != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(imageFile, height: 100),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Campo Nombre
                      TextField(
                        controller: nameController,
                        maxLines: isManual ? 5 : 1,
                        decoration: InputDecoration(
                          labelText: isManual
                              ? "Introduce un producto por línea (uno por línea o separados por coma)"
                              : "Nombre del producto",
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Campo Cantidad (Solo para entrada simple)
                      if (!isManual)
                        TextField(
                          controller: quantityController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Cantidad (por defecto 1)",
                            border: OutlineInputBorder(),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),

                      if (!isManual) const SizedBox(height: 16),

                      // Campo Categoría
                      DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: "Categoría",
                            border: OutlineInputBorder(),
                          ),
                          // Establecer el valor inicial aquí
                          value: selectedCategory, 
                          // Usamos la lista 'displayCategories' que incluye la sugerencia
                          items: displayCategories.map((String category) {
                            return DropdownMenuItem<String>(
                              value: category,
                              child: Text(category),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setStateDialog(() {
                                selectedCategory = newValue;
                              });
                            }
                          }),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text("Cancelar"),
                  ),
                  FilledButton(
                    onPressed: () {
                      final name = nameController.text.trim();
                      final quantityText = quantityController.text.trim();
                      final quantity =
                          isManual ? 1 : (int.tryParse(quantityText) ?? 1);

                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("El nombre no puede estar vacío")),
                        );
                        return;
                      }

                      Navigator.pop(context, {
                        'name': name,
                        'quantity': quantity,
                        'category': selectedCategory, // Devolvemos la categoría
                      });
                    },
                    child: const Text("Guardar"),
                  ),
                ],
              );
            });
          },
        );
      },
    );
  }
  // ----------------------------------------------------------------------

  /// ✍️ Manual multi-línea
  Future<void> _addManual() async {
    // 🔄 Llamamos al diálogo con la categoría por defecto para entrada manual
    final result = await _showNameAndQuantityDialog(
        isManual: true, initialCategory: 'General'); 

    if (result != null) {
      final text = result['name'] as String;
      // 🔄 En la entrada manual, forzamos la categoría 'General' por simplicidad
      const category = 'General'; 

      final lines = text
          .split(RegExp(r'[\n,;]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (lines.isEmpty) return;

      final confirm = await _confirmMultiple(lines);

      if (confirm) {
        for (final product in lines) {
          await _addItem(widget.familyId,
              name: product, quantity: 1, category: category);
        }
      }
    }
  }

  /// 🔊 Añadir desde voz
  Future<void> _addFromVoice() async {
    // ... (Lógica de Speech-to-Text permanece igual) ...
    _voiceText = "";

    var status = await Permission.microphone.status;
    if (status.isDenied || status.isRestricted) {
      status = await Permission.microphone.request();
    }

    if (status.isPermanentlyDenied) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Permiso de micrófono bloqueado"),
          content: const Text(
            "Has denegado el acceso al micrófono. "
            "Actívalo manualmente en los ajustes de tu dispositivo.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              label: const Text("Abrir ajustes"),
            ),
          ],
        ),
      );
      return;
    }

    if (!status.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Debes conceder acceso al micrófono para usar esta función",
          ),
        ),
      );
      return;
    }

    final available = await _speech.initialize();
    if (!available) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No se pudo inicializar el reconocimiento de voz"),
        ),
      );
      return;
    }

    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            void startListening() async {
              final ok = await _speech.initialize();
              if (ok) {
                setStateDialog(() => _isListening = true);
                _speech.listen(
                  onResult: (val) {
                    setStateDialog(() => _voiceText = val.recognizedWords);
                  },
                );
              }
            }

            void stopListening() {
              _speech.stop();
              setStateDialog(() => _isListening = false);
            }

            return AlertDialog(
              title: const Text("Añadir por voz"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _voiceText.isEmpty ? "Habla ahora..." : _voiceText,
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  IconButton(
                    iconSize: 64,
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? Colors.red : Colors.grey,
                    ),
                    onPressed: _isListening ? stopListening : startListening,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _speech.stop();
                    Navigator.pop(context);
                  },
                  child: const Text("Cancelar"),
                ),
                FilledButton(
                  onPressed: () async {
                    _speech.stop();
                    
                    if (_voiceText.trim().isNotEmpty) {
                      
                      final products = _voiceText
                          .split(RegExp(r'[,\ny]'))
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList();
                      
                      
                      if (products.isNotEmpty) {
                        final confirm = await _confirmMultiple(products);
                
                        if (confirm) {
                          for (final product in products) {
                            await _addItem(widget.familyId,
                                name: product,
                                quantity: 1,
                                category: 'General'); // Voz siempre va a General por ahora
                          }
                        }
                      }
                    }
                    Navigator.pop(context);
                  },
                  child: const Text("Aceptar"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _confirmMultiple(List<String> products) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Confirmar productos"),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children:
                    products.map((p) => ListTile(title: Text(p))).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancelar"),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Guardar todos"),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// 📸 Procesamiento de imagen (OCR) - Modificado para usar el nuevo diálogo
  Future<void> _processImage(File image) async {
    // 1. Extraer líneas de texto (ordenadas visualmente)
    final extractedLines = await OcrHelper.extractTextFromImage(image); 
    
    String initialName = "Nuevo producto";
    String initialCategory = 'General'; 
    int initialQuantity = 1;

    String? selectedText;
    if (extractedLines.isNotEmpty) {
        // 2. Permitir al usuario seleccionar/confirmar el nombre principal
        selectedText = await OcrHelper.showTextSuggestionsDialog(context, extractedLines);
    }

    if (selectedText != null && selectedText.trim().isNotEmpty) {
      initialName = selectedText.trim();
      
      // 3. ANÁLISIS INTELIGENTE: Sugerir categoría y cantidad basado en el texto seleccionado
      final suggested = OcrHelper.suggestCategoryAndQuantity(initialName);
      
      initialName = suggested.suggestedName;
      initialCategory = suggested.suggestedCategory;
      initialQuantity = suggested.suggestedQuantity;
    }

    // 4. Mostrar el diálogo de confirmación con todas las sugerencias pre-rellenadas
    final result = await _showNameAndQuantityDialog(
      initialName: initialName,
      imageFile: image,
      isManual: false,
      initialCategory: initialCategory,
      initialQuantity: initialQuantity, // Pasamos la cantidad sugerida
    );

    if (result != null) {
      final finalName = result['name'] as String;
      final finalQuantity = result['quantity'] as int;
      final finalCategory = result['category'] as String;

      try {
        await _addItem(
          widget.familyId,
          imageFile: image,
          name: finalName,
          quantity: finalQuantity,
          category: finalCategory,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Producto “$finalName” (x$finalQuantity) guardado en $finalCategory.",
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo guardar el producto: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // --- FUNCIÓN: Diálogo para gestionar categorías (Eliminar) ---
  Future<void> _showCategoryManagementDialog() async {
    return showDialog(
      context: context,
      builder: (context) {
        return StreamBuilder<List<String>>(
          stream: _controller.getCategories(widget.familyId),
          builder: (context, snapshot) {
            final categories = snapshot.data ?? ['General'];
            final customCategories = categories.where((c) => c != 'General').toList();

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            return AlertDialog(
              title: const Text("Gestionar Categorías"),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: customCategories.length,
                  itemBuilder: (context, index) {
                    final category = customCategories[index];
                    return ListTile(
                      title: Text(category),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          // 1. Contar cuántos ítems hay en esa categoría
                          final count = await _controller.countItemsInCategory(widget.familyId, category);
                          
                          if (count > 0) {
                            // 2. Preguntar al usuario si está seguro
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text("Confirmar borrado"),
                                content: Text(
                                    "La categoría '$category' contiene $count productos. ¿Deseas borrarlos todos y reasignarlos a 'General'?"),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
                                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Borrar y Reasignar")),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await _controller.deleteCategory(widget.familyId, category);
                              if (mounted) Navigator.pop(context); // Cierra el diálogo de gestión
                            }
                          } else {
                            // Si no hay ítems, borrar directamente
                            await _controller.deleteCategory(widget.familyId, category);
                            if (mounted) Navigator.pop(context); // Cierra el diálogo de gestión
                            // Es importante recargar la lista de categorías si se está viendo
                            // pero el StreamBuilder ya lo hará automáticamente.
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cerrar"),
                ),
                TextButton(
                  onPressed: () {
                    // Llamamos a la función de añadir categoría desde aquí
                    Navigator.pop(context); // Cierra el diálogo de gestión
                    _showAddCategoryDialogFromManagement();
                  }, 
                  child: const Text("Añadir Nueva"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- FUNCIÓN: Diálogo para añadir Categoría (Versión corregida para ser llamada) ---
  Future<void> _showAddCategoryDialogFromManagement() async {
    _newCategoryController.clear();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Añadir Nueva Categoría"),
          content: TextField(
            controller: _newCategoryController,
            decoration: const InputDecoration(
              labelText: "Nombre de la categoría",
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) {
              Navigator.pop(context, true);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancelar"),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Añadir"),
            ),
          ],
        );
      },
    ).then((confirmed) async {
      if (confirmed == true) {
        final name = _newCategoryController.text.trim();
        if (name.isNotEmpty && name.toLowerCase() != 'general') {
          await _controller.addCategory(widget.familyId, name);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Categoría '$name' añadida.")),
            );
          }
        } else if (name.toLowerCase() == 'general') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text("La categoría 'General' no se puede crear.")),
            );
          }
        }
      }
    });
    // Después de añadir, volvemos a abrir el diálogo de gestión
    if(mounted) {
        await _showCategoryManagementDialog();
    }
  }
  // ---------------------------------------------------

  // --- FUNCIÓN MODIFICADA: Construir la Lista o la Cuadrícula Categorizada ---
  Widget _buildCategorizedList(
      List<ShoppingItem> items, List<String> categories,
      {bool isHistory = false}) {
    final filteredItems = _query.isEmpty
        ? items
        : items
            .where((item) =>
                item.name.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    if (filteredItems.isEmpty && _query.isNotEmpty) {
      return const Center(child: Text("No hay productos que coincidan con la búsqueda."));
    }
    if (filteredItems.isEmpty && _query.isEmpty) {
      return const Center(child: Text("La lista está vacía"));
    }

    // 2. Agrupar los ítems filtrados por su categoría
    final Map<String, List<ShoppingItem>> groupedItems = {};
    for (var cat in categories) {
      groupedItems[cat] = [];
    }
    for (var item in filteredItems) {
      groupedItems.putIfAbsent(item.category, () => []);
      groupedItems[item.category]?.add(item);
    }

    // 🏆 Separar y Priorizar categorías: Vacías primero
    final List<String> emptyCategories = [];
    final List<String> nonEmptyCategories = [];

    for (var cat in categories) {
      final categoryItems = groupedItems[cat] ?? [];
      if (categoryItems.isEmpty) {
        emptyCategories.add(cat);
      } else {
        nonEmptyCategories.add(cat);
      }
    }

    final prioritizedCategories = [...emptyCategories, ...nonEmptyCategories];

    // 3. Crear una lista aplanada de widgets (Encabezados + Items)
    final List<Widget> listWidgets = [];

    final isListMode = _selectedView == 0;
    final int gridColumns = isListMode ? 1 : (_selectedView == 1 ? 2 : 3);


    for (var category in prioritizedCategories) {
      final categoryItems = groupedItems[category] ?? [];
      final isCategoryEmpty = categoryItems.isEmpty;

      // === 3.1 ENCABEZADO DE CATEGORÍA (DragTarget) ===
      listWidgets.add(
        DragTarget<ShoppingItem>(
          onAcceptWithDetails: (details) async {
            final itemToMove = details.data;
            // DESACTIVAR MODO DE MOVIMIENTO AL SOLTAR
            setState(() {
              _isCategoryMoveMode = false;
            });
            if (itemToMove.category != category) {
              await _controller.moveItemToCategory(
                  widget.familyId, itemToMove, category);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text("${itemToMove.name} movido a $category")),
              );
            }
          },
          // Solo permite soltar si el ítem que se arrastra no pertenece ya a esta categoría
          onWillAcceptWithDetails: (details) =>
              details.data.category != category, 
          builder: (context, candidateData, rejectedData) {
            final isTarget = candidateData.isNotEmpty;
            return Container(
              margin: const EdgeInsets.only(top: 16, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isTarget ? Colors.yellow.shade100 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color:
                        isTarget ? Colors.yellow.shade700 : Colors.transparent),
              ),
              child: Row(
                children: [
                  Text(
                    category,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const Spacer(),
                  Text(
                    isCategoryEmpty
                        ? 'Vacía'
                        : '${categoryItems.length} productos',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          },
        ),
      );

      // === 3.2 ITEMS BAJO LA CATEGORÍA ===
      if (categoryItems.isNotEmpty && !_isCategoryMoveMode) {
        if (isListMode) {
          // A. VISTA DE LISTA (ItemTile) - Mantiene el Drag and Drop en el ItemTile
          for (var item in categoryItems) {
            listWidgets.add(
              LongPressDraggable<ShoppingItem>(
                data: item,
                onDragStarted: () { setState(() { _isCategoryMoveMode = true; }); },
                onDragCompleted: () { setState(() { _isCategoryMoveMode = false; }); },
                onDraggableCanceled: (_, __) { setState(() { _isCategoryMoveMode = false; }); },
                feedback: Opacity(
                  opacity: 0.85,
                  child: Material(
                    elevation: 8,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width,
                      child: ItemTile(item: item.copyWith(name: item.name, quantity: item.quantity), familyId: widget.familyId, controller: _controller, isHistory: isHistory),
                    ),
                  ),
                ),
                childWhenDragging: Opacity(opacity: 0.0, child: ItemTile(item: item, familyId: widget.familyId, controller: _controller, isHistory: isHistory)),
                child: ItemTile(item: item, familyId: widget.familyId, controller: _controller, isHistory: isHistory),
              ),
            );
          }
        } else {
          // B. VISTA DE CUADRÍCULA (GridView dentro del ListView)
          final List<Widget> draggableGridItems = categoryItems.map((item) => 
                // 🟢 Cada ItemGrid se convierte en Draggable
                LongPressDraggable<ShoppingItem>(
                  data: item,
                  // 🟢 Lógica de Drag and Drop
                  onDragStarted: () { setState(() { _isCategoryMoveMode = true; }); },
                  onDragCompleted: () { setState(() { _isCategoryMoveMode = false; }); },
                  onDraggableCanceled: (_, __) { setState(() { _isCategoryMoveMode = false; }); },
                  
                  // Feedback visual para el arrastre (usando el mismo ItemGrid pero opaco)
                  feedback: Opacity(
                    opacity: 0.85,
                    child: Material(
                      elevation: 8,
                      child: SizedBox(
                        // Ajustamos el ancho y alto del feedback para que coincida con el tamaño del grid
                        width: (MediaQuery.of(context).size.width / gridColumns) - 16, 
                        height: (MediaQuery.of(context).size.width / gridColumns) - 16,
                        child: ItemGrid(item: item.copyWith(name: item.name, quantity: item.quantity), familyId: widget.familyId, controller: _controller, columns: gridColumns, isHistory: isHistory),
                      ),
                    ),
                  ),
                  
                  // Ocultar el ItemGrid original cuando se arrastra
                  childWhenDragging: Opacity(opacity: 0.0, child: ItemGrid(item: item, familyId: widget.familyId, controller: _controller, columns: gridColumns, isHistory: isHistory)),
                  
                  // ItemGrid real
                  child: ItemGrid(
                    item: item,
                    familyId: widget.familyId,
                    controller: _controller,
                    columns: gridColumns,
                    isHistory: isHistory,
                  ),
                ),
          ).toList();
          
          listWidgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(), // Deshabilita el scroll interno
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridColumns,
                  crossAxisSpacing: 8.0,
                  mainAxisSpacing: 8.0,
                  childAspectRatio: 1.0, 
                ),
                itemCount: draggableGridItems.length,
                itemBuilder: (context, index) {
                  // Devolvemos el ItemGrid envuelto en LongPressDraggable
                  return draggableGridItems[index]; 
                },
              ),
            ),
          );
        }
      }
    }

    // 4. Devolvemos una sola lista (ListView) que contiene Encabezados + Tiles/Grids
    return ListView(
      children: listWidgets,
    );
  }

  // Mantenemos la estructura de _buildList pero delegamos la lógica de lista simple
  Widget _buildList(List<ShoppingItem> items, {bool isHistory = false}) {
    // 🟢 _buildList ahora solo envuelve el StreamBuilder y llama al categorizador.
    return StreamBuilder<List<String>>(
      stream: _controller.getCategories(widget.familyId),
      builder: (context, snapshot) {
        final categories = snapshot.data ?? ['General'];
        // Usamos KeyedSubtree para forzar la reconstrucción de la lista de categorías
        return KeyedSubtree(
          key: ValueKey('CategorizedList-${categories.length}-${_selectedView}'),
          child: _buildCategorizedList(items, categories, isHistory: isHistory),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('families')
            .doc(widget.familyId)
            .snapshots(),
        builder: (context, snapshot) {
          final familyData = snapshot.data?.data() as Map<String, dynamic>?;
          final familyName = familyData?['name'] ?? "Familia";

          return Scaffold(
            appBar: AppBar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              title: Row(
                children: [
                  const Icon(Icons.family_restroom, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(familyName),
                ],
              ),
              actions: [
                // 🟢 Botón de Configuración de Fuente (¡NUEVO Y FUNCIONAL!)
                IconButton(
                  icon: const Icon(Icons.text_fields),
                  tooltip: 'Tamaño de Fuente',
                  onPressed: () {
                    // Accedemos al MyApp widget que contiene el PreferencesService
                    final appWidget = MyApp.of(context); 
                    final preferencesService = appWidget.preferencesService;
                    
                    showDialog(
                      context: context,
                      builder: (ctx) => FontScaleSettingsDialog(
                        preferencesService: preferencesService, 
                      ),
                    );
                  },
                ),
                // Botón para Gestionar Categorías (Añadir/Borrar)
                IconButton(
                  icon: const Icon(Icons.category),
                  tooltip: 'Gestionar Categorías',
                  onPressed: _showCategoryManagementDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: 'Cerrar sesión',
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (context) => const AuthScreen()),
                      (Route<dynamic> route) => false,
                    );
                  },
                ),
              ],
              bottom: const TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                tabs: [
                  Tab(icon: Icon(Icons.shopping_cart), text: "Lista"),
                  Tab(icon: Icon(Icons.history), text: "Histórico"),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                // 🛒 LISTA (ACTIVA)
                Column(
                  children: [
                    _buildSearchField("Buscar producto"),
                    Expanded(
                      child: StreamBuilder<List<ShoppingItem>>(
                        stream: _controller.getItems(widget.familyId,
                            bought: false),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          // Llama a _buildList, que ahora maneja la categorización para listas y grids
                          return _buildList(snapshot.data!, isHistory: false);
                        },
                      ),
                    ),
                  ],
                ),
                // 🧾 HISTÓRICO
                Column(
                  children: [
                    _buildSearchField("Buscar en histórico"),
                    Expanded(
                      child: StreamBuilder<List<ShoppingItem>>(
                        stream:
                            _controller.getItems(widget.familyId, bought: true),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          // Llama a _buildList, que ahora maneja la categorización para listas y grids
                          return _buildList(snapshot.data!, isHistory: true);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _selectedView,
              onTap: (index) => setState(() => _selectedView = index),
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.list), label: "Lista"),
                BottomNavigationBarItem(
                    icon: Icon(Icons.grid_view), label: "Grid (2)"),
                BottomNavigationBarItem(
                    icon: Icon(Icons.grid_3x3), label: "Grid (3)"),
              ],
            ),
            // El FAB se mantiene para añadir por foto, voz o manual
            floatingActionButton: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: SpeedDial(
                    icon: Icons.add,
                    activeIcon: Icons.close,
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    foregroundColor: Colors.white,
                    children: [
                      SpeedDialChild(
                        child: const Icon(Icons.photo),
                        label: "Elegir de galería",
                        onTap: _addFromGallery,
                      ),
                      SpeedDialChild(
                        child: const Icon(Icons.edit),
                        label: "Añadir manualmente",
                        onTap: _addManual,
                      ),
                      SpeedDialChild(
                        child: const Icon(Icons.mic),
                        label: "Añadir por voz",
                        onTap: _addFromVoice,
                      ),
                    ],
                  ),
                ),
                FloatingActionButton(
                  onPressed: _addFromCamera,
                  tooltip: "Añadir con cámara",
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.camera_alt),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchField(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.search),
          border: const OutlineInputBorder(),
        ),
        onChanged: (value) => setState(() => _query = value.trim()),
      ),
    );
  }
}