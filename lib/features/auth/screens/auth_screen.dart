import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:drift/drift.dart' show Value;
import '../../../core/database/database.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../../core/presentation/glass_widgets.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/config/firebase_config.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = ref.read(authServiceProvider);

    try {
      if (_isSignUp) {
        final res = await authService.signUpWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
        final db = ref.read(databaseProvider);
        await db.into(db.userSettings).insertOnConflictUpdate(
          UserSettingsCompanion(
            id: const Value(1),
            isOnboarded: const Value(true),
            updatedAt: Value(DateTime.now()),
          ),
        );
        ref.invalidate(isOnboardedProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                res.user != null
                    ? 'Account created successfully!'
                    : 'Check your email for confirmation link.',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        await authService.signInWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
        final db = ref.read(databaseProvider);
        await db.into(db.userSettings).insertOnConflictUpdate(
          UserSettingsCompanion(
            id: const Value(1),
            isOnboarded: const Value(true),
            updatedAt: Value(DateTime.now()),
          ),
        );
        ref.invalidate(isOnboardedProvider);
        ref.read(syncNotifierProvider.notifier).triggerSync();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitGoogleAuth() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = ref.read(authServiceProvider);

    try {
      await authService.signInWithGoogle();
      final db = ref.read(databaseProvider);
      await db.into(db.userSettings).insertOnConflictUpdate(
        UserSettingsCompanion(
          id: const Value(1),
          isOnboarded: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
      ref.invalidate(isOnboardedProvider);
      ref.read(syncNotifierProvider.notifier).triggerSync();
    } catch (e) {
      setState(() {
        final err = e.toString().replaceAll('Exception:', '').trim();
        _errorMessage = err;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _continueAsGuest() async {
    await ref.read(guestModeProvider.notifier).enableGuestMode();
  }

  Future<void> _showForgotPasswordDialog() async {
    final resetEmailController = TextEditingController(text: _emailController.text);
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: Text(
          'Reset Password',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter your registered email address to receive password reset instructions.',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Email Address',
                labelStyle: const TextStyle(color: Colors.white60),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () async {
              if (resetEmailController.text.trim().isNotEmpty) {
                try {
                  await ref.read(authServiceProvider).resetPassword(resetEmailController.text);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password reset email sent!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  }
                }
              }
            },
            child: const Text('Send Email'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0F0C20),
              const Color(0xFF1A1A2E),
              primaryColor.withValues(alpha: 0.15),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Logo & Branding
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryColor.withValues(alpha: 0.15),
                        border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 54,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Quantro',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isSignUp
                          ? 'Create your account to sync data securely'
                          : 'Welcome back! Sign in to restore your cloud data',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white60,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Glassmorphic Auth Card
                    GlassContainer(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Login / Sign Up Tab Toggle
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTabButton(
                                      title: 'Sign In',
                                      isActive: !_isSignUp,
                                      onTap: () => setState(() {
                                        _isSignUp = false;
                                        _errorMessage = null;
                                      }),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildTabButton(
                                      title: 'Create Account',
                                      isActive: _isSignUp,
                                      onTap: () => setState(() {
                                        _isSignUp = true;
                                        _errorMessage = null;
                                      }),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              if (_errorMessage != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: GoogleFonts.inter(
                                            color: Colors.redAccent,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Email Input
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Email Address',
                                  labelStyle: const TextStyle(color: Colors.white60),
                                  prefixIcon: const Icon(Icons.email_outlined, color: Colors.white60),
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.05),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!val.contains('@')) return 'Enter a valid email address';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Password Input
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  labelStyle: const TextStyle(color: Colors.white60),
                                  prefixIcon: const Icon(Icons.lock_outline, color: Colors.white60),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: Colors.white60,
                                    ),
                                    onPressed: () => setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    }),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.05),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                validator: (val) {
                                  if (val == null || val.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),

                              if (!_isSignUp) ...[
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _showForgotPasswordDialog,
                                    child: Text(
                                      'Forgot Password?',
                                      style: GoogleFonts.inter(
                                        color: primaryColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(height: 16),
                              ],

                              // Primary Action Button (Submit)
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 4,
                                ),
                                onPressed: _isLoading ? null : _submitEmailAuth,
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Text(
                                        _isSignUp ? 'Create Account' : 'Sign In',
                                        style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),

                              if (FirebaseConfig.isConfigured) ...[
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Text(
                                        'OR',
                                        style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                                      ),
                                    ),
                                    Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Google Sign-In Button
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(Icons.g_mobiledata, size: 28, color: Colors.redAccent),
                                  label: Text(
                                    'Continue with Google',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  onPressed: _isLoading ? null : _submitGoogleAuth,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Offline Local-Only Mode Option
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.cloud_off_rounded, size: 20, color: Colors.white60),
                      label: Text(
                        'Continue in Offline Mode (Local Only)',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onPressed: _continueAsGuest,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
          ),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? Colors.white : Colors.white60,
          ),
        ),
      ),
    );
  }
}
