// lib/screens/main_screen_decider.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Importa las pantallas que decide mostrar (Asegúrate de que estas rutas sean correctas)
import 'auth_screen.dart';
import 'biometric_lock_screen.dart';
import 'family_selection_screen.dart';

/// Widget que decide qué pantalla mostrar al inicio:
class MainScreenDecider extends StatelessWidget {
  const MainScreenDecider({super.key});

  @override
  Widget build(BuildContext context) {
    // Escucha los cambios de autenticación (login/logout)
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        // Si hay un usuario logueado
        if (snapshot.data != null) {
          // Si está logueado, verifica el bloqueo biométrico
          return const BiometricLockScreen(
            child: FamilySelectionScreen(),
          );
        }

        // Si el estado es activo y no hay usuario, vamos a la pantalla de login
        if (snapshot.connectionState == ConnectionState.active && snapshot.data == null) {
          return const AuthScreen();
        }
        
        // Mientras se espera la conexión inicial o el estado (loading)
        return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}