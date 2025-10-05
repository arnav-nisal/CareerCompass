import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:adaptive_career_roadmap_builder/screens/welcome_page.dart';
import 'package:adaptive_career_roadmap_builder/screens/qna_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        final user = snap.data;
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (user == null) return const WelcomePage();

        // Block password-provider users until emailVerified is true
        final isPasswordProvider =
            user.providerData.any((p) => p.providerId == 'password');
        if (isPasswordProvider && !user.emailVerified) {
          return const _VerifyBlockedPage();
        }

        return const QnaPage();
      },
    );
  }
}

// Minimal blocking page shown if an unverified password user slips through.
// Users will normally land on EmailCheckPage immediately after signup.
class _VerifyBlockedPage extends StatelessWidget {
  const _VerifyBlockedPage();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '(unknown)';
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
                        'Email verification required',
                        style: TextStyle(
                            color: Color(0xFFE0E1DD),
                            fontSize: 20,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please verify: $email',
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                try {
                                  await user?.sendEmailVerification();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Verification email sent')),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text('Failed to send: $e')),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.send),
                              label: const Text('Resend email'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                try {
                                  await FirebaseAuth.instance.currentUser
                                      ?.reload();
                                  if (context.mounted) {
                                    final refreshed =
                                        FirebaseAuth.instance.currentUser;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              (refreshed?.emailVerified ??
                                                      false)
                                                  ? 'Verified!'
                                                  : 'Not verified yet')),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text('Check failed: $e')),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('I\'ve verified'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {},
                        child: const Text('Open email app',
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
