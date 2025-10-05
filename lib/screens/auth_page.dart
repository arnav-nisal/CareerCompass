// lib/screens/auth_page.dart
import 'package:adaptive_career_roadmap_builder/shared/animated_background.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _isLogin = true;

  // Shared controllers to allow email prefill transfer between forms
  final TextEditingController _sharedEmailCtrl = TextEditingController();

  // Toggle and transfer email text between forms
  void _toggleForm() {
    setState(() {
      _isLogin = !_isLogin;
    });
  }

  @override
  void dispose() {
    _sharedEmailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SharedAnimatedBackground(
      builder: (context, color) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: SingleChildScrollView(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: _isLogin
                        ? LoginForm(
                            key: const ValueKey('login'),
                            color: color,
                            onToggle: _toggleForm,
                            sharedEmailCtrl: _sharedEmailCtrl,
                          )
                        : SignupForm(
                            key: const ValueKey('signup'),
                            color: color,
                            onToggle: _toggleForm,
                            sharedEmailCtrl: _sharedEmailCtrl,
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// --- LOGIN FORM WIDGET ---
class LoginForm extends StatefulWidget {
  final Color color;
  final VoidCallback onToggle;
  final TextEditingController sharedEmailCtrl;

  const LoginForm({
    super.key,
    required this.color,
    required this.onToggle,
    required this.sharedEmailCtrl,
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Bind login email field to shared controller for prefill
    _emailController = widget.sharedEmailCtrl;
  }

  @override
  void dispose() {
    // Do not dispose shared controller here; parent owns it
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No user found for that email. Please sign up.';
          break;
        case 'wrong-password':
        case 'invalid-credential':
          message =
              'Invalid credentials. Please check your email and password.';
          break;
        default:
          message = e.message ?? 'An error occurred. Please try again.';
      }
      setState(() {
        _errorMessage = message;
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final acct = await GoogleSignIn(scopes: const ['email']).signIn();
      if (acct == null) {
        setState(() => _isLoading = false); // user canceled
        return;
      }
      final auth = await acct.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = 'Google Sign-In failed: ${e.message ?? e.code}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Google Sign-In failed: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.color;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Welcome Back!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 34,
            fontWeight: FontWeight.bold,
            color: Color(0xFFE0E1DD),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Sign in to continue your journey',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: 'Inter', fontSize: 16, color: Color(0xFFB0B3B8)),
        ),
        const SizedBox(height: 40),
        _buildTextField(
          controller: _emailController,
          label: 'Email',
          icon: Icons.email_outlined,
          enabled: !_isLoading,
        ),
        const SizedBox(height: 20),
        _buildTextField(
          controller: _passwordController,
          label: 'Password',
          icon: Icons.lock_outline,
          obscureText: true,
          enabled: !_isLoading,
        ),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red[400]),
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 20),
        _buildAuthButton(context, 'Login', _signInWithEmail, accent,
            isLoading: _isLoading),
        const SizedBox(height: 20),
        _buildDivider(),
        const SizedBox(height: 20),
        _buildGoogleSignInButtonDark(context, _signInWithGoogle, accent,
            isLoading: _isLoading),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Don't have an account?",
                style: TextStyle(color: Color(0xFFB0B3B8))),
            TextButton(
              onPressed: _isLoading ? null : widget.onToggle,
              child: Text('Sign Up',
                  style: TextStyle(fontWeight: FontWeight.bold, color: accent)),
            ),
          ],
        ),
      ],
    );
  }
}

// --- SIGN-UP FORM WIDGET ---
class SignupForm extends StatefulWidget {
  final Color color;
  final VoidCallback onToggle;
  final TextEditingController sharedEmailCtrl;

  const SignupForm({
    super.key,
    required this.color,
    required this.onToggle,
    required this.sharedEmailCtrl,
  });

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Bind signup email field to shared controller for prefill
    _emailController = widget.sharedEmailCtrl;
  }

  @override
  void dispose() {
    // Do not dispose shared controller; parent owns it
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUpWithEmail() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = "Passwords do not match.";
        _isLoading = false;
      });
      return;
    }
    try {
      final email = _emailController.text.trim();
      final pass = _passwordController.text;

      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: pass,
      );

      // Ask Firebase to send verification email
      await cred.user?.sendEmailVerification();

      // Sign out to block access until verified
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      // Show in-place sheet (no navigation away from AuthPage)
      await _showVerifySheet(context,
          email: email, plainPassword: pass, accent: widget.color);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'An error occurred. Please try again.';
        _isLoading = false;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final acct = await GoogleSignIn(scopes: const ['email']).signIn();
      if (acct == null) {
        setState(() => _isLoading = false);
        return;
      }
      final auth = await acct.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = 'Google Sign-In failed: ${e.message ?? e.code}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Google Sign-In failed: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.color;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Create Account',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 34,
            fontWeight: FontWeight.bold,
            color: Color(0xFFE0E1DD),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Start your journey with us today',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: 'Inter', fontSize: 16, color: Color(0xFFB0B3B8)),
        ),
        const SizedBox(height: 40),
        _buildTextField(
          controller: _emailController,
          label: 'Email',
          icon: Icons.email_outlined,
          enabled: !_isLoading,
        ),
        const SizedBox(height: 20),
        _buildTextField(
          controller: _passwordController,
          label: 'Password',
          icon: Icons.lock_outline,
          obscureText: true,
          enabled: !_isLoading,
        ),
        const SizedBox(height: 20),
        _buildTextField(
          controller: _confirmPasswordController,
          label: 'Confirm Password',
          icon: Icons.lock_outline,
          obscureText: true,
          enabled: !_isLoading,
        ),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red[400]),
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 20),
        _buildAuthButton(context, 'Sign Up', _signUpWithEmail, accent,
            isLoading: _isLoading),
        const SizedBox(height: 20),
        _buildDivider(),
        const SizedBox(height: 20),
        _buildGoogleSignInButtonDark(context, _signInWithGoogle, accent,
            isLoading: _isLoading),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Already have an account?",
                style: TextStyle(color: Color(0xFFB0B3B8))),
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      // Ensure the typed email carries over to Login
                      widget.onToggle();
                    },
              child: Text('Login',
                  style: TextStyle(fontWeight: FontWeight.bold, color: accent)),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showVerifySheet(
    BuildContext context, {
    required String email,
    required String plainPassword,
    required Color accent,
  }) async {
    bool sending = false;

    Future<void> resend() async {
      if (sending) return;
      sending = true;
      try {
        // Ephemeral sign-in to call sendEmailVerification, then sign out
        final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: plainPassword,
        );
        await cred.user?.sendEmailVerification();
        await FirebaseAuth.instance.signOut();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Verification email sent')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to resend: $e')),
          );
        }
      } finally {
        sending = false;
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withAlpha(180),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.58,
          minChildSize: 0.45,
          maxChildSize: 0.9,
          builder: (context, scrollCtrl) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(230),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border.all(color: accent.withAlpha(80)),
              ),
              child: SingleChildScrollView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(top: 6, bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Verify your email',
                            style: TextStyle(
                              color: Color(0xFFE0E1DD),
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close, color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'We sent a verification link to:',
                      style: TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      email,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tip: If you don\'t see it, please check your Spam or Junk folder.',
                      style: TextStyle(color: Colors.white60),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: resend,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent.withAlpha(150),
                          foregroundColor: const Color(0xFFE0E1DD),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.send),
                        label: const Text('Resend email'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Always close sheet and return to AuthPage view
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('If verified, log in now.')),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE0E1DD),
                          side: BorderSide(color: accent.withAlpha(160)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.login),
                        label: const Text('I’ve verified'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// --- SHARED WIDGETS ---
Widget _buildTextField({
  required TextEditingController controller,
  required String label,
  required IconData icon,
  bool obscureText = false,
  bool enabled = true,
}) {
  return TextField(
    controller: controller,
    obscureText: obscureText,
    enabled: enabled,
    style: const TextStyle(color: Color(0xFFE0E1DD)),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFFB0B3B8)),
      prefixIcon: Icon(icon, color: const Color(0xFFB0B3B8)),
      filled: true,
      fillColor: Colors.black.withAlpha(76),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

Widget _buildAuthButton(
  BuildContext context,
  String text,
  VoidCallback onPressed,
  Color color, {
  bool isLoading = false,
}) {
  return ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: color.withAlpha(153),
      foregroundColor: const Color(0xFFE0E1DD),
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
      elevation: 8,
      shadowColor: color.withAlpha(128),
    ),
    onPressed: isLoading ? null : onPressed,
    child: isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child:
                CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        : Text(
            text,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
  );
}

// Dark themed Google button with "G" logo
Widget _buildGoogleSignInButtonDark(
  BuildContext context,
  VoidCallback onPressed,
  Color accent, {
  bool isLoading = false,
}) {
  return ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.black.withAlpha(180),
      foregroundColor: const Color(0xFFE0E1DD),
      padding: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
      elevation: 8,
      shadowColor: accent.withAlpha(128),
      side: BorderSide(color: accent.withAlpha(160), width: 1),
    ),
    onPressed: isLoading ? null : onPressed,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!isLoading)
          Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: Image.asset(
              'assets/google_logo.png',
              height: 20,
              width: 20,
            ),
          ),
        if (isLoading)
          const SizedBox(
            height: 20,
            width: 20,
            child:
                CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        else
          const Text(
            'Sign in with Google',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
      ],
    ),
  );
}

Widget _buildDivider() {
  return const Row(
    children: [
      Expanded(child: Divider(color: Color(0xFFB0B3B8))),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.0),
        child: Text('OR', style: TextStyle(color: Color(0xFFB0B3B8))),
      ),
      Expanded(child: Divider(color: Color(0xFFB0B3B8))),
    ],
  );
}
