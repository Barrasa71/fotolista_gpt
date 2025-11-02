import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../services/cache_service.dart';
import '../widgets/cached_firebase_image.dart';

class FamilySettingsScreen extends StatefulWidget {
  final String familyId;
  final String currentName;

  const FamilySettingsScreen({
    super.key,
    required this.familyId,
    required this.currentName,
  });

  @override
  State<FamilySettingsScreen> createState() => _FamilySettingsScreenState();
}

class _FamilySettingsScreenState extends State<FamilySettingsScreen> {
  final FirestoreService _db = FirestoreService();
  final StorageService _storage = StorageService();

  File? _newImage; // imagen recortada final
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAndCropImage() async {
    final picker = ImagePicker();

    // 👇 Mostrar diálogo para elegir cámara o galería
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Seleccionar foto"),
        content: const Text("¿De dónde quieres obtener la foto?"),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.photo),
            label: const Text("Galería"),
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
          ),
          TextButton.icon(
            icon: const Icon(Icons.camera_alt),
            label: const Text("Cámara"),
            onPressed: () => Navigator.pop(context, ImageSource.camera),
          ),
        ],
      ),
    );

    if (source == null) return;

    // 📸 Elegir o hacer foto
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    // ✂️ Recortar la imagen antes de subirla
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Recortar foto',
          toolbarColor: Theme.of(context).colorScheme.primary,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
        IOSUiSettings(
          title: 'Recortar foto',
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
      ],
    );

    if (cropped != null) {
      setState(() => _newImage = File(cropped.path));
    }
  }

  Future<void> _saveChanges() async {
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty && newName != widget.currentName) {
      await _db.updateFamilyName(widget.familyId, newName);
    }
    if (_newImage != null) {
      final url = await _storage.uploadFamilyImage(_newImage!, widget.familyId);
      await _db.updateFamilyImage(widget.familyId, url);
      await AppCacheManager.instance.removeFile(url);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _deleteImage() async {
    await _storage.deleteFamilyImage(widget.familyId);
    await _db.updateFamilyImage(widget.familyId, null);

    final url = await _db.getFamilyImage(widget.familyId);
    if (url != null) {
      await AppCacheManager.instance.removeFile(url);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ajustes de familia")),
      body: FutureBuilder<String?>(
        future: _db.getFamilyImage(widget.familyId),
        builder: (ctx, snapshot) {
          final url = snapshot.data;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _newImage != null
                      ? Image.file(
                          _newImage!,
                          height: 240,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : (url != null
                          ? CachedFirebaseImage(
                              imageUrl: url,
                              isCircle: false,
                              height: 240,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              height: 240,
                              width: double.infinity,
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.group,
                                  size: 80, color: Colors.grey),
                            )),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _pickAndCropImage,
                icon: const Icon(Icons.photo),
                label: const Text("Cambiar foto"),
              ),
              if (url != null)
                ElevatedButton.icon(
                  onPressed: _deleteImage,
                  icon: const Icon(Icons.delete),
                  label: const Text("Eliminar foto"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade300,
                    foregroundColor: Colors.white,
                  ),
                ),
              const Divider(height: 32),
              const SizedBox(height: 16),
              const Text("Nombre de la familia:"),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "Nombre",
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _saveChanges,
                icon: const Icon(Icons.check),
                label: const Text("Guardar"),
              ),
            ],
          );
        },
      ),
    );
  }
}
