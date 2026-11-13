import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'auth_gate.dart';
import 'player_auth_service.dart';

/// Sign up and sign in for ORBIT.
/// The app-wide cosmic background is already provided by MaterialApp.builder.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const _logoAsset = 'lib/core/assets/orbit_wordmark.png';
  static final _usernamePattern = RegExp(r'^[a-z0-9_]{5,12}$');

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isSignUp = true;
  bool _loading = false;
  bool _hidePassword = true;
  bool _hideConfirm = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _switchMode() {
    if (_loading) return;
    _passwordController.clear();
    _confirmController.clear();
    setState(() {
      _isSignUp = !_isSignUp;
      _hidePassword = true;
      _hideConfirm = true;
    });
  }

  String? _validateUsername(String? value) {
    final username = value?.trim() ?? '';
    if (username.isEmpty) return 'Enter your username.';
    if (!_usernamePattern.hasMatch(username)) {
      return 'Use 5–12 lowercase letters, numbers, or _.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').length < 6) return 'Minimum 6 characters.';
    return null;
  }

  String? _validateConfirmation(String? value) {
    if (value != _passwordController.text) {
      return 'Passwords do not match.';
    }
    return null;
  }

  String _messageForAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'Username already taken. Try another one.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect username or password.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'operation-not-allowed':
        return 'Email/Password authentication is disabled.';
      case 'network-request-failed':
        return 'Connection failed. Check your Firebase connection.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF402039),
        ),
      );
  }

  Future<void> _submit() async {
    if (_loading || !(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text;

      if (_isSignUp) {
        await PlayerAuthService.instance.register(
          username: username,
          password: password,
        );
      } else {
        await PlayerAuthService.instance.login(
          username: username,
          password: password,
        );
      }

      if (!mounted) return;
      // AuthGate decides whether an existing profile should go to
      // ProfileSetup or Home, including on sign-in.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
            (route) => false,
      );
    } on FirebaseAuthException catch (error) {
      if (mounted) _showError(_messageForAuthError(error));
    } on FormatException catch (error) {
      if (mounted) _showError(error.message);
    } catch (error) {
      debugPrint('ORBIT auth error: ${error.runtimeType}');
      if (mounted) _showError('Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _brandHeader() {
    return Column(
      children: [
        Image.asset(
          _logoAsset,
          width: 204,
          height: 72,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('ORBIT logo not found: $error');
            return const SizedBox(
              height: 72,
              child: Center(
                child: Text(
                  'ORBIT',
                  style: TextStyle(
                    color: AppColors.softLilac,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        const Text(
          'A world that remembers you.',
          style: TextStyle(color: AppColors.softLilac, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  InputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  Widget _inputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    required String? Function(String?) validator,
    bool isPassword = false,
    bool isConfirmation = false,
    bool isLast = false,
  }) {
    final hidden = isConfirmation ? _hideConfirm : _hidePassword;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.softLilac,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 9),
        TextFormField(
          controller: controller,
          validator: validator,
          autocorrect: false,
          enableSuggestions: !isPassword,
          keyboardType: isPassword ? TextInputType.visiblePassword : TextInputType.text,
          textCapitalization: TextCapitalization.none,
          obscureText: isPassword && hidden,
          textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
          autofillHints: isPassword
              ? [isConfirmation || _isSignUp
              ? AutofillHints.newPassword
              : AutofillHints.password]
              : const [AutofillHints.username],
          onFieldSubmitted: isLast ? (_) => _submit() : null,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
          ),
          cursorColor: AppColors.primaryPink,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
            prefixIcon: Icon(icon, size: 19, color: AppColors.softLilac),
            suffixIcon: isPassword
                ? IconButton(
              tooltip: hidden ? 'Show password' : 'Hide password',
              onPressed: () => setState(() {
                if (isConfirmation) {
                  _hideConfirm = !_hideConfirm;
                } else {
                  _hidePassword = !_hidePassword;
                }
              }),
              icon: Icon(
                hidden
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.softLilac,
                size: 19,
              ),
            )
                : null,
            filled: true,
            fillColor: const Color(0x990D0A20),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 17,
            ),
            enabledBorder: _inputBorder(const Color(0x775C477A)),
            focusedBorder: _inputBorder(AppColors.primaryPink, width: 1.5),
            errorBorder: _inputBorder(AppColors.danger),
            focusedErrorBorder: _inputBorder(AppColors.danger),
          ),
        ),
      ],
    );
  }

  Widget _primaryButton() {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPink.withAlpha(65),
            blurRadius: 24,
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _loading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
        child: _loading
            ? const SizedBox(
          width: 23,
          height: 23,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isSignUp ? 'Create Your Account' : 'Enter Your Universe',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _authCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xB51D1538),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0x887F60AD)),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isSignUp ? 'Create Your Account' : 'Welcome Back, Traveler',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  _isSignUp
                      ? 'Your story begins among the stars.'
                      : 'Your universe has been waiting for you.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.softLilac,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 28),
                _inputField(
                  label: 'Username',
                  hint: 'Your cosmic username',
                  controller: _usernameController,
                  icon: Icons.alternate_email_rounded,
                  validator: _validateUsername,
                ),
                const SizedBox(height: 18),
                _inputField(
                  label: 'Password',
                  hint: 'Enter your password',
                  controller: _passwordController,
                  icon: Icons.lock_outline_rounded,
                  validator: _validatePassword,
                  isPassword: true,
                  isLast: !_isSignUp,
                ),
                if (_isSignUp) ...[
                  const SizedBox(height: 18),
                  _inputField(
                    label: 'Confirm Password',
                    hint: 'Repeat your password',
                    controller: _confirmController,
                    icon: Icons.verified_user_outlined,
                    validator: _validateConfirmation,
                    isPassword: true,
                    isConfirmation: true,
                    isLast: true,
                  ),
                ],
                const SizedBox(height: 28),
                _primaryButton(),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _isSignUp
                          ? 'Already exploring ORBIT? '
                          : 'New to this universe? ',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    TextButton(
                      onPressed: _loading ? null : _switchMode,
                      child: Text(
                        _isSignUp ? 'Sign In' : 'Sign Up',
                        style: const TextStyle(
                          color: AppColors.primaryPink,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight > 48
                      ? constraints.maxHeight - 48
                      : 0,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _brandHeader(),
                        const SizedBox(height: 26),
                        _authCard(),
                        const SizedBox(height: 22),
                        const Text(
                          '✦  FIND YOUR PLACE AMONG THE STARS  ✦',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            letterSpacing: 1.2,
                            fontSize: 10,
                          ),
                        ),
                        if (_isSignUp) ...[
                          const SizedBox(height: 10),
                          const Text(
                            'Use a fictional username. Never share your real identity.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
