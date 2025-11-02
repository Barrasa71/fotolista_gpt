import 'package:flutter/material.dart';
// 🟢 CORRECCIÓN: Usamos el prefijo 'local_auth' para la clase AuthenticationOptions
import 'package:local_auth/local_auth.dart' as local_auth; 
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BiometricLockScreen extends StatefulWidget {
  final Widget child;

  const BiometricLockScreen({super.key, required this.child});

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  final local_auth.LocalAuthentication _auth = local_auth.LocalAuthentication();
  bool _authenticated = false;
  bool _authFailed = false;
  bool _isCheckingAuth = true; 

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    setState(() {
      _authFailed = false;
      _isCheckingAuth = true; 
    });

    try {
      final bool canCheckBiometrics = await _auth.canCheckBiometrics;
      final bool isDeviceSupported = await _auth.isDeviceSupported();
      final List<local_auth.BiometricType> availableBiometrics = // Usamos local_auth.BiometricType
          await _auth.getAvailableBiometrics();

      // Si no hay biometría disponible o soportada, accedemos directamente
      if (!canCheckBiometrics || !isDeviceSupported || availableBiometrics.isEmpty) {
        setState(() {
          _authenticated = true;
          _isCheckingAuth = false;
        });
        return;
      }

      // 🟢 CORRECCIÓN CLAVE: Usamos 'authOptions' como segundo parámetro
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Identifícate para acceder a la aplicación',
        // 🟢 Usamos la clase importada con prefijo
        options: const local_auth.AuthenticationOptions( 
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      setState(() {
        _authenticated = didAuthenticate;
        _authFailed = !didAuthenticate;
        _isCheckingAuth = false;
      });

    } on PlatformException catch (e) {
      print("💥 Error en autenticación biométrica: $e");
      setState(() {
        _authFailed = true;
        _isCheckingAuth = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_authenticated) {
      return widget.child;
    }
    
    // Muestra el cargador mientras se verifica o falla
    return Scaffold(
      body: Center(
        child: _isCheckingAuth
            ? const CircularProgressIndicator() // Muestra cargador mientras verifica
            : _authFailed
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fingerprint, size: 80, color: Colors.red), // Icono más claro para fallo
                    const SizedBox(height: 16),
                    const Text(
                      "Autenticación fallida",
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _authenticate, 
                      icon: const Icon(Icons.refresh),
                      label: const Text("Reintentar"),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text("Cambiar de cuenta"),
                    ),
                  ],
                )
              : const CircularProgressIndicator(), 
      ),
    );
  }
}