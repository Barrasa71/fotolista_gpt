// lib/screens/auth_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fotolista_gpt/screens/family_selection_screen.dart';
import 'package:fotolista_gpt/screens/reset_pasword_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _auth = FirebaseAuth.instance;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // --- MÉTODOS (permanecen iguales) ---

  Future<void> _signInWithGoogle() async {
    try {
      setState(() => _loading = true);

      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize();

      final googleUser = await googleSignIn.authenticate(
        scopeHint: ['email', 'profile'],
      );
      final googleAuth = googleUser.authentication;

      if (googleAuth.idToken == null) {
        throw Exception('No se pudo obtener idToken de Google Sign-In');
      }

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);

      // ✅ Después de iniciar sesión con Google, navega a la pantalla principal (familias):
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const FamilySelectionScreen()),
        );
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitEmailPassword() async {
    try {
      setState(() => _loading = true);

      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (_isLogin) {
        // modo login
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        // 🔁 Navegar directamente a pantalla principal tras login
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const FamilySelectionScreen()),
          );
        }
      } else {
        // modo registro
        if (password != _confirmPasswordController.text.trim()) {
          _showError("Las contraseñas no coinciden");
          return;
        }
        await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Cuenta creada con éxito")),
          );
        }
        _emailController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();
        setState(() {
          _isLogin = true;
        });
        return; // salir sin más para que re-renderice como login
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  // --- WIDGET PRINCIPAL ---
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    
    // 🟢 Degradado moderno: más sutil y limpio, como un fondo de Material 3
    const modernGradient = LinearGradient(
      colors: [Color(0xFFE8F5E9), Color(0xFFE0F7FA)], // Tonos pastel y limpios
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    return Scaffold(
      // 🟢 Usamos el degradado sutil
      body: Container(
        decoration: const BoxDecoration(gradient: modernGradient),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            // 🟢 Tarjeta moderna con más elevación y bordes suaves
            child: Card(
              elevation: 12, // Más elevado
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28), // Bordes más grandes
              ),
              child: Padding(
                padding: const EdgeInsets.all(32), // Más padding interior
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 🟢 SOLUCIÓN DEFINITIVA
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16), // Recorte sutil
                      child: Image.asset(
                        'assets/carro_compra.png',
                        height: 150, // Aumentamos el tamaño
                        // Usamos un color de fondo (por ejemplo, el de la tarjeta) para asegurarnos
                        // de que el área transparente se rellene.
                        // El color se aplicará al lienzo antes de renderizar la imagen.
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 🟢 Título dinámico
                    Text(
                      _isLogin ? "Bienvenido" : "Crear una cuenta",
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isLogin ? "Inicia sesión para continuar" : "Únete a la lista de compras inteligente",
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // 🟢 CAMPOS DE TEXTO ESTILIZADOS
                    _buildInputField(
                      controller: _emailController,
                      label: 'Correo electrónico',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    
                    // 🟢 CAMPO DE CONTRASEÑA ESTILIZADO
                    _buildPasswordInput(
                      controller: _passwordController,
                      label: 'Contraseña',
                      isObscure: _obscurePassword,
                      onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    
                    // 🟢 Envoltura con animación para cambio suave entre login/registro
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) {
                        // Deslizamiento sutil al aparecer/desaparecer
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, -0.1),
                            end: Offset.zero,
                          ).animate(animation),
                          child: FadeTransition(opacity: animation, child: child),
                        );
                      },
                      child: _isLogin
                          ? Column(
                              key: const ValueKey('login_options'),
                              children: [
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const ResetPasswordScreen()),
                                      );
                                    },
                                    child: Text(
                                      "¿Olvidaste tu contraseña?",
                                      style: TextStyle(
                                        color: scheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            )
                          : Column(
                              key: const ValueKey('register_confirm'),
                              children: [
                                const SizedBox(height: 16),
                                // 🟢 CAMPO DE CONFIRMACIÓN ESTILIZADO
                                _buildPasswordInput(
                                  controller: _confirmPasswordController,
                                  label: 'Confirmar contraseña',
                                  isObscure: _obscureConfirmPassword,
                                  onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                    ),
                    
                    if (_loading)
                      const CircularProgressIndicator()
                    else ...[
                      // 🟢 Botón principal moderno y con buen contraste
                      FilledButton(
                        onPressed: _submitEmailPassword,
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.primary,
                          foregroundColor: scheme.onPrimary,
                          minimumSize: const Size(double.infinity, 52), // Más alto
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12), // Bordes más suaves
                          ),
                          elevation: 4, // Sombra para resaltar
                        ),
                        child: Text(
                          _isLogin ? "Entrar" : "Crear cuenta",
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),

                      // 🟢 Botón de Google estilizado (SIEMPRE VISIBLE)
                      OutlinedButton.icon(
                        onPressed: _signInWithGoogle,
                        icon: Image.asset(
                          "assets/google_logo.png", // Asegúrate de tener este asset
                          height: 20, // Icono más pequeño para un look limpio
                          width: 20,
                        ),
                        label: Text(
                          "Continuar con Google",
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                          side: BorderSide(color: scheme.outline), // Borde más sutil
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 🟢 Toggle de modo
                      TextButton(
                        onPressed: () {
                          setState(() => _isLogin = !_isLogin);
                        },
                        child: Text(
                          _isLogin
                              ? "¿No tienes cuenta? Regístrate"
                              : "¿Ya tienes cuenta? Inicia sesión",
                          style: TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🟢 Helper para Inputs (Más limpio en el build)
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: scheme.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), // Bordes redondeados
        ),
        filled: true,
        fillColor: scheme.surfaceVariant.withOpacity(0.2), // Relleno suave
      ),
      keyboardType: keyboardType,
      style: TextStyle(color: scheme.onSurface),
    );
  }

  // 🟢 Helper para Inputs de Contraseña (Más limpio en el build)
  Widget _buildPasswordInput({
    required TextEditingController controller,
    required String label,
    required bool isObscure,
    required VoidCallback onToggle,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(Icons.lock_outline, color: scheme.primary),
        suffixIcon: IconButton(
          icon: Icon(
            isObscure ? Icons.visibility_off : Icons.visibility,
            color: scheme.secondary,
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: scheme.surfaceVariant.withOpacity(0.2),
      ),
      obscureText: isObscure,
      style: TextStyle(color: scheme.onSurface),
    );
  }
}