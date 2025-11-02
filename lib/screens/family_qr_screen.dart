import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class FamilyQrScreen extends StatelessWidget {
  final String familyId;
  const FamilyQrScreen({super.key, required this.familyId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Código QR de la familia")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            QrImageView(
              data: familyId,
              version: QrVersions.auto,
              size: 250.0,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.circle,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.circle,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SelectableText(
                  "Código: $familyId",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: "Copiar código",
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: familyId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Código copiado al portapapeles")),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
