import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'player_auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../home_screen.dart';
import '../profile/profile_setup_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
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

  void _changeMode(bool signUp) {
    setState(() {
      _isSignUp = signUp;
      _confirmController.clear();
    });
  }

  String _authError(FirebaseAuthException error) {
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
        return 'Enable Email/Password in Firebase Authentication.';
      case 'network-request-failed':
        return 'Connection failed. Check Firebase Emulator.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;

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

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => _isSignUp
              ? const ProfileSetupScreen()
              : const HomeScreen(),
        ),
            (route) => false,
      );
    } on FirebaseAuthException catch (error) {
      if (mounted) _showError(_authError(error));
    } on FormatException catch (error) {
      if (mounted) _showError(error.message);
    } catch (error) {
      debugPrint('Authentication failed: ${error.runtimeType}');
      if (mounted) {
        _showError('Something went wrong. Try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF402039),
      ),
    );
  }

  Widget _inputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    bool password = false,
    bool confirm = false,
  }) {
    final hidden = confirm ? _hideConfirm : _hidePassword;

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
          autocorrect: false,
          enableSuggestions: !password,
          obscureText: password && hidden,
          textInputAction: password
              ? TextInputAction.done
              : TextInputAction.next,
          onFieldSubmitted: password ? (_) => _submit() : null,
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
            prefixIcon: Icon(
              icon,
              color: AppColors.softLilac,
              size: 19,
            ),
            suffixIcon: password
                ? IconButton(
              onPressed: () {
                setState(() {
                  if (confirm) {
                    _hideConfirm = !_hideConfirm;
                  } else {
                    _hidePassword = !_hidePassword;
                  }
                });
              },
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
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0x775C477A),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.primaryPink,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.danger,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.danger,
              ),
            ),
          ),
          validator: (value) {
            final text = value ?? '';

            if (confirm) {
              return text == _passwordController.text
                  ? null
                  : 'Passwords do not match.';
            }

            if (password) {
              return text.length >= 6
                  ? null
                  : 'Minimum 6 characters.';
            }

            if (!RegExp(r'^[a-zA-Z0-9_]{3,20}$')
                .hasMatch(text.trim())) {
              return 'Use 3-20 letters, numbers, or _.';
            }

            return null;
          },
        ),
      ],
    );
  }

  Widget _gradientButton() {
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
            spreadRadius: 1,
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
              _isSignUp
                  ? 'Create Your Account'
                  : 'Enter Your Universe',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 18,
          sigmaY: 18,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0x991D1538),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: const Color(0x887F60AD),
              width: 1.1,
            ),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Text(
                  _isSignUp
                      ? 'Create Your Account'
                      : 'Welcome Back, Traveler',
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
                const SizedBox(height: 30),

                _inputField(
                  label: 'Username',
                  hint: 'Your cosmic username',
                  controller: _usernameController,
                  icon: Icons.alternate_email_rounded,
                ),
                const SizedBox(height: 18),

                _inputField(
                  label: 'Password',
                  hint: 'Enter your password',
                  controller: _passwordController,
                  icon: Icons.lock_outline_rounded,
                  password: true,
                ),

                if (_isSignUp) ...[
                  const SizedBox(height: 18),
                  _inputField(
                    label: 'Confirm Password',
                    hint: 'Repeat your password',
                    controller: _confirmController,
                    icon: Icons.verified_user_outlined,
                    password: true,
                    confirm: true,
                  ),
                ],

                const SizedBox(height: 28),
                _gradientButton(),

                const SizedBox(height: 25),
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
                      onPressed: _loading
                          ? null
                          : () => _changeMode(!_isSignUp),
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
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'lib/core/assets/bg.jpg',
              fit: BoxFit.cover,
            ),
          ),
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0xB5090718),
            ),
          ),

          // Cosmic glow behind the glass card
          Positioned(
            top: 120,
            right: -80,
            child: IgnorePointer(
              child: Container(
                width: 230,
                height: 230,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryPurple.withAlpha(90),
                      blurRadius: 110,
                      spreadRadius: 28,
                    ),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 28,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 56,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 440,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.satellite_alt_rounded,
                              color: AppColors.primaryPink,
                              size: 55,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'O R B I T',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 27,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'A world that remembers you.',
                              style: TextStyle(
                                color: AppColors.softLilac,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 32),

                            _glassCard(),

                            const SizedBox(height: 25),
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
                              const SizedBox(height: 12),
                              const Text(
                                'Use a fictional username. '
                                    'Never share your real identity.',
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
        ],
      ),
    );
  }
}
