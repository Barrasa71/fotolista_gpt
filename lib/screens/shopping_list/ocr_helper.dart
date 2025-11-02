import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// 🆕 Nueva clase para estructurar la salida de la sugerencia del OCR
class SuggestedItem {
  final String suggestedName;
  final String suggestedCategory;
  final int suggestedQuantity;

  SuggestedItem({
    required this.suggestedName,
    this.suggestedCategory = 'General',
    this.suggestedQuantity = 1,
  });
}

class OcrHelper {
  
  // 🆕 Base de datos de palabras clave para sugerencias de categorías
  // 💡 Nota: Puedes expandir esta lista para más precisión.
  static const Map<String, String> _CATEGORY_KEYWORDS = {
    'leche': 'Lácteos',
    'yogur': 'Lácteos',
    'queso': 'Lácteos',
    'mantequilla': 'Lácteos',

    'manzana': 'Frutas y Verduras',
    'platano': 'Frutas y Verduras',
    'tomate': 'Frutas y Verduras',
    'patata': 'Frutas y Verduras',

    'pan': 'Panadería',
    'bollo': 'Panadería',
    'barra': 'Panadería',
    'cereal': 'Panadería',

    'pasta': 'Despensa',
    'arroz': 'Despensa',
    'aceite': 'Despensa',
    'azucar': 'Despensa',
    'sal': 'Despensa',
    
    'pollo': 'Carne y Pescado',
    'carne': 'Carne y Pescado',
    'pescado': 'Carne y Pescado',
    'salmon': 'Carne y Pescado',
    
    'cerveza': 'Bebidas',
    'refresco': 'Bebidas',
    'agua': 'Bebidas',
  };

  /// 🔁 Extraer texto desde una imagen (ordenado visualmente)
  static Future<List<String>> extractTextFromImage(File image) async {
    final textRecognizer = TextRecognizer();
    try {
      final input = InputImage.fromFile(image);
      final result = await textRecognizer.processImage(input);

      final List<Map<String, dynamic>> linesData = [];

      // 🔹 Recorremos bloques y líneas con sus posiciones
      for (final block in result.blocks) {
        for (final line in block.lines) {
          final rect = line.boundingBox;
          linesData.add({
            'text': line.text.trim(),
            'y': rect.top,
            'height': rect.height,
          });
                }
      }

      // 🔹 Filtramos líneas vacías o no relevantes
      final filtered = linesData.where((line) {
        final text = line['text'] as String;
        if (text.isEmpty) return false;
        if (RegExp(r'^\s*[\d\W]+\s*$').hasMatch(text)) return false;
        return true;
      }).toList();

      // 🔹 Orden visual: primero por posición Y (de arriba a abajo)
      // y si están en la misma línea, por tamaño (más grande primero)
      filtered.sort((a, b) {
        final yComp = (a['y'] as double).compareTo(b['y'] as double);
        if (yComp.abs() < 10) {
          // Si están en la misma altura, ordenamos por altura del texto
          return (b['height'] as double).compareTo(a['height'] as double);
        }
        return yComp;
      });

      // 🔹 Extraemos solo el texto, eliminando duplicados
      final orderedTexts = filtered
          .map((e) => e['text'] as String)
          .toSet()
          .toList();

      return orderedTexts;
    } finally {
      textRecognizer.close();
    }
  }

  // 🆕 FUNCIÓN DE ANÁLISIS INTELIGENTE
  /// 🧠 Analiza el texto seleccionado para sugerir cantidad y categoría.
  static SuggestedItem suggestCategoryAndQuantity(String accumulatedText) {
    final lowerCaseText = accumulatedText.toLowerCase();
    String suggestedCategory = 'General';
    int suggestedQuantity = 1; 

    // 1. Clasificación por Palabras Clave (Keywords)
    for (final keywordEntry in _CATEGORY_KEYWORDS.entries) {
      final keyword = keywordEntry.key;
      final category = keywordEntry.value;

      if (lowerCaseText.contains(keyword)) {
        suggestedCategory = category;
        break; 
      }
    }

    // 2. Extracción de Cantidad (Simple)
    final quantityMatch = RegExp(r'^(\d+)\s*(ud|und|unidades|x|kg|gr|lt)').firstMatch(lowerCaseText.trim());
    
    if (quantityMatch != null) {
      suggestedQuantity = int.tryParse(quantityMatch.group(1) ?? '1') ?? 1;
    }
    
    // 3. Limpieza del Nombre
    String finalName = accumulatedText;
    if (quantityMatch != null) {
      final matchText = quantityMatch.group(0)!;
      // Eliminamos el texto de cantidad del nombre para limpiarlo
      finalName = accumulatedText.substring(matchText.length).trim();
      
      // Si el nombre queda vacío después de la limpieza, usamos la categoría como fallback
      if (finalName.isEmpty) {
          finalName = suggestedCategory != 'General' ? suggestedCategory : accumulatedText;
      }
    }

    return SuggestedItem(
      suggestedName: finalName.isEmpty ? accumulatedText : finalName,
      suggestedCategory: suggestedCategory,
      suggestedQuantity: suggestedQuantity,
    );
  }


  /// 📋 Diálogo con selección múltiple, edición, acumulación (Ahora usa ' · ' como separador)
  static Future<String?> showTextSuggestionsDialog(
    BuildContext context,
    List<String> candidates,
  ) async {
    if (candidates.isEmpty) return null;

    final selected = <String>{};

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          void toggleText(String text) {
            if (selected.contains(text)) {
              selected.remove(text);
            } else {
              selected.add(text);
            }
            setStateDialog(() {});
          }

          void addEditedText(String edited) {
            if (edited.isNotEmpty && !selected.contains(edited)) {
              selected.removeWhere((t) => t == edited); 
              selected.add(edited);
              setStateDialog(() {});
            }
          }

          // 🟢 CAMBIO CLAVE: Usamos ' · ' como separador
          String accumulated = selected.join(" · "); 

          return AlertDialog(
            title: const Text("Selecciona Nombres", style: TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (accumulated.isNotEmpty) ...[
                    // 🟢 MEJORA VISUAL: Mostrar texto acumulado de forma destacada
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      ),
                      child: Text(
                        accumulated,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: candidates.length,
                      itemBuilder: (context, i) {
                        final text = candidates[i];
                        final isAdded = selected.contains(text);
                        return ListTile(
                          leading: Icon(
                            isAdded
                                ? Icons.check_circle
                                : Icons.add_circle_outline,
                            color: isAdded ? Colors.green : Colors.grey,
                          ),
                          title: Text(text),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit, color: Colors.grey),
                            tooltip: "Editar",
                            onPressed: () async {
                              final controller =
                                  TextEditingController(text: text);
                              final edited = await showDialog<String>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text("Editar texto"),
                                  content: TextField(
                                    controller: controller,
                                    autofocus: true,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, null),
                                      child: const Text("Cancelar"),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(
                                          context, controller.text.trim()),
                                      child: const Text("Aceptar"),
                                    ),
                                  ],
                                ),
                              );
                              if (edited != null && edited.isNotEmpty) {
                                addEditedText(edited);
                              }
                            },
                          ),
                          onTap: () => toggleText(text),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text("Cancelar"),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(ctx, accumulated.isEmpty ? null : accumulated),
                child: const Text("Confirmar selección"),
              ),
            ],
          );
        },
      ),
    );
  }
}