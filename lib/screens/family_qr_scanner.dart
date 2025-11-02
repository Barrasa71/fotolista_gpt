import 'package:flutter/material.dart';
import 'package:fotolista_gpt/services/family_services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class FamilyQrScanner extends StatefulWidget {
  const FamilyQrScanner({super.key});

  @override
  State<FamilyQrScanner> createState() => _FamilyQrScannerState();
}

class _FamilyQrScannerState extends State<FamilyQrScanner> {
  final FamilyService _familyService = FamilyService();
  bool _processing = false;

  void _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final barcode = capture.barcodes.first;

    if (barcode.rawValue != null) {
      setState(() => _processing = true);

      final familyId = barcode.rawValue!;
      print("📷 QR detectado: $familyId");

      await _familyService.joinFamily(familyId);

      if (mounted) {
        Navigator.pop(context); // volvemos atrás tras unirnos
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Escanear QR")),
      body: MobileScanner(
        onDetect: _onDetect,
        controller: MobileScannerController(
          facing: CameraFacing.back,
          torchEnabled: false,
        ),
      ),
    );
  }
}
