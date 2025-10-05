// lib/screens/email_check_page.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_page.dart';

class EmailCheckPage extends StatefulWidget {
  final String email;
  // Pass the raw password only for a short-lived resend session; do NOT persist.
  final String? plainPassword;

  const EmailCheckPage({
    super.key,
    required this.email,
    this.plainPassword,
  });

  @override
  State<EmailCheckPage> createState() => _EmailCheckPageState();
}

class _EmailCheckPageState extends State<EmailCheckPage> {
  bool _sending = false;
  bool _navigating = false;
  bool _opening = false;

  Future<void> _resendVerification() async {
    if (_sending) return;
    setState(() => _sending = true);

    try {
      // If already signed in (unlikely here), try directly
      final current = FirebaseAuth.instance.currentUser;
      if (current != null) {
        await current.sendEmailVerification();
      } else {
        // Ephemeral re-auth just to send the email, then sign out.
        if (widget.plainPassword == null || widget.plainPassword!.isEmpty) {
          throw Exception(
              'Password not available to resend. Try logging in to resend.');
        }
        final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: widget.email,
          password: widget.plainPassword!,
        );
        await cred.user?.sendEmailVerification();
        await FirebaseAuth.instance.signOut();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification email sent')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to resend: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openEmailApp() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      // Try common inbox links; fallback to generic mailto:
      // Many Android devices handle "mailto:" with preferred mail app chooser.
      final Uri mailto = Uri(
        scheme: 'mailto',
        path: widget.email,
        query:
            'subject=Email verification&body=Please follow the link sent by the app.',
      );
      if (!await launchUrl(mailto, mode: LaunchMode.externalApplication)) {
        throw Exception('No mail app handler found');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open mail app: $e')),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _goToAuthPage() async {
    if (_navigating) return;
    setState(() => _navigating = true);
    try {
      if (!mounted) return;
      // Go straight to AuthPage (login view), not Welcome
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthPage()),
        (route) => false,
      );
    } finally {
      if (mounted) setState(() => _navigating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                color: Colors.white.withAlpha(18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.mark_email_read,
                          color: Colors.white70, size: 40),
                      const SizedBox(height: 12),
                      const Text(
                        'Verify your email',
                        style: TextStyle(
                            color: Color(0xFFE0E1DD),
                            fontSize: 20,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'We sent a verification link to:',
                        style: TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.email,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _sending ? null : _resendVerification,
                              icon: _sending
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.send),
                              label: Text(
                                  _sending ? 'Sending...' : 'Resend email'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _navigating ? null : _goToAuthPage,
                              icon: _navigating
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.login),
                              label: const Text('I\'ve verified'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _opening ? null : _openEmailApp,
                        icon: _opening
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.mail_outline,
                                color: Colors.white70, size: 18),
                        label: const Text('Open email app',
                            style: TextStyle(color: Colors.white70)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
