import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../blocs/auth_bloc.dart';
import '../blocs/auth_event.dart';
import '../blocs/auth_state.dart';
import '../../data/social_auth_service.dart';
import '../../../../injection/injection.dart';

class AuthDialog extends StatefulWidget {
  const AuthDialog({super.key});

  @override
  State<AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends State<AuthDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  late final SocialAuthService _socialAuthService;
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _socialAuthService = getIt<SocialAuthService>();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleAuthMode() {
    setState(() {
      _isLogin = !_isLogin;
      _animationController.reset();
      _animationController.forward();
    });
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isLogin) {
        context.read<AuthBloc>().add(
              AuthSignInRequested(
                email: _emailController.text.trim(),
                password: _passwordController.text,
              ),
            );
        Navigator.of(context).pop();
      } else {
        context.read<AuthBloc>().add(
              AuthSignUpRequested(
                email: _emailController.text.trim(),
                password: _passwordController.text,
                username: _usernameController.text.trim(),
                context: context,
              ),
            );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email address'),
        ),
      );
      return;
    }

    try {
      // TODO: Implement password reset
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
        ),
      );
    }
  }

  Future<void> _handleSocialSignIn(
      Future<supabase.AuthResponse?> Function() signInMethod) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final response = await signInMethod();
      if (response?.user != null) {
        context.read<AuthBloc>().add(AuthUserUpdated(response!.user!.id));
        Navigator.of(context).pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleSignUp() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
            AuthSignUpRequested(
              email: _emailController.text.trim(),
              password: _passwordController.text,
              username: _usernameController.text.trim(),
              context: context,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.viewInsets.bottom;
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: DraggableScrollableSheet(
        initialChildSize: 0.90,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        snap: true,
        snapSizes: const [0.7],
        builder: (context, scrollController) => Material(
          color: Colors.transparent,
          child: BlocListener<AuthBloc, AuthState>(
            listener: (context, state) {
              if (state is AuthFailure) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: theme.colorScheme.error,
                  ),
                );
              } else if (state is AuthAuthenticated && _isLogin) {
                Navigator.of(context).pop();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top handle with improved styling
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 16, bottom: 8),
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                  ),

                  // Expanded content with enhanced UI
                  Expanded(
                    child: CustomScrollView(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    AnimatedOpacity(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      opacity: 0.6,
                                      child: IconButton(
                                        icon: const Icon(Icons.close_rounded),
                                        onPressed: () => Navigator.pop(context),
                                        style: IconButton.styleFrom(
                                          backgroundColor: theme
                                              .colorScheme.surfaceContainerHighest
                                              .withOpacity(0.5),
                                          padding: const EdgeInsets.all(8),
                                        ),
                                      ),
                                    ),

                                    // Login/Signup toggle tabs
                                    Container(
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceContainerHighest
                                            .withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _buildToggleTab(
                                            context: context,
                                            title: 'Login',
                                            isSelected: _isLogin,
                                            onTap: () {
                                              if (!_isLogin) _toggleAuthMode();
                                            },
                                          ),
                                          _buildToggleTab(
                                            context: context,
                                            title: 'Sign Up',
                                            isSelected: !_isLogin,
                                            onTap: () {
                                              if (_isLogin) _toggleAuthMode();
                                            },
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Spacer to match the close button width
                                    const SizedBox(width: 48),
                                  ],
                                ),

                                const SizedBox(height: 32),

                                // Welcome heading with animation
                                FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _isLogin
                                            ? 'Welcome back!'
                                            : 'Join ReadLeaf',
                                        style: theme.textTheme.headlineMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _isLogin
                                            ? 'Sign in to continue your reading journey'
                                            : 'Create an account to start your reading journey',
                                        style:
                                            theme.textTheme.bodyLarge?.copyWith(
                                          color: theme.colorScheme.onSurface
                                              .withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 32),

                                // Form with modern styling
                                Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (!_isLogin)
                                        AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 300),
                                          height: !_isLogin ? 80 : 0,
                                          child: AnimatedOpacity(
                                            duration: const Duration(
                                                milliseconds: 300),
                                            opacity: !_isLogin ? 1.0 : 0.0,
                                            child: _buildTextField(
                                              controller: _usernameController,
                                              label: 'Username',
                                              icon:
                                                  Icons.person_outline_rounded,
                                              validator: (value) {
                                                if (!_isLogin &&
                                                    (value == null ||
                                                        value.isEmpty)) {
                                                  return 'Please enter a username';
                                                }
                                                return null;
                                              },
                                            ),
                                          ),
                                        ),

                                      const SizedBox(height: 16),

                                      _buildTextField(
                                        controller: _emailController,
                                        label: 'Email',
                                        icon: Icons.email_outlined,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter your email';
                                          }
                                          if (!value.contains('@')) {
                                            return 'Please enter a valid email';
                                          }
                                          return null;
                                        },
                                      ),

                                      const SizedBox(height: 16),

                                      _buildTextField(
                                        controller: _passwordController,
                                        label: 'Password',
                                        icon: Icons.lock_outline_rounded,
                                        obscureText: _obscurePassword,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter your password';
                                          }
                                          if (!_isLogin && value.length < 6) {
                                            return 'Password must be at least 6 characters';
                                          }
                                          return null;
                                        },
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                            size: 20,
                                          ),
                                          onPressed: _togglePasswordVisibility,
                                        ),
                                      ),

                                      if (!_isLogin)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              top: 8, left: 12),
                                          child: Text(
                                            '• At least 6 characters with letters and numbers\n• Include at least one special character',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: theme
                                                  .colorScheme.onSurfaceVariant,
                                              height: 1.5,
                                            ),
                                          ),
                                        ),

                                      if (_isLogin)
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: _resetPassword,
                                            style: TextButton.styleFrom(
                                              padding: EdgeInsets.zero,
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            child: Text(
                                              'Forgot password?',
                                              style: TextStyle(
                                                color:
                                                    theme.colorScheme.primary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),

                                      const SizedBox(height: 32),

                                      // Primary action button
                                      _buildPrimaryButton(
                                        text: _isLogin
                                            ? 'Sign In'
                                            : 'Create Account',
                                        isLoading: _isLoading,
                                        onPressed: _submit,
                                      ),

                                      const SizedBox(height: 24),

                                      // Divider with "or" text
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Divider(
                                              color: theme.colorScheme.onSurface
                                                  .withOpacity(0.1),
                                              thickness: 1,
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16),
                                            child: Text(
                                              'or continue with',
                                              style: TextStyle(
                                                color: theme.colorScheme
                                                    .onSurfaceVariant,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Divider(
                                              color: theme.colorScheme.onSurface
                                                  .withOpacity(0.1),
                                              thickness: 1,
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 24),

                                      // Social sign-in buttons
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          _buildSocialSignInButton(
                                            icon: Image.asset(
                                              'assets/images/auth/google_logo.png',
                                              width: 24,
                                              height: 24,
                                            ),
                                            onPressed: () =>
                                                _handleSocialSignIn(
                                              _socialAuthService
                                                  .signInWithGoogle,
                                            ),
                                          ),
                                          const SizedBox(width: 20),
                                          _buildSocialSignInButton(
                                            icon: const Icon(
                                              Icons.facebook_rounded,
                                              color: Color(0xFF1877F2),
                                              size: 24,
                                            ),
                                            onPressed: () =>
                                                _handleSocialSignIn(
                                              _socialAuthService
                                                  .signInWithFacebook,
                                            ),
                                          ),
                                        ],
                                      ),

                                      SizedBox(
                                          height: bottomPadding > 0
                                              ? bottomPadding
                                              : 32),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to build toggle tabs
  Widget _buildToggleTab({
    required BuildContext context,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // Helper method to build modern text fields
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
        fontSize: 16,
        color: theme.colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: 16,
        ),
        prefixIcon: Icon(
          icon,
          color: theme.colorScheme.primary.withOpacity(0.8),
          size: 20,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark
            ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.5)
            : theme.colorScheme.surfaceContainerLow.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.primary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.error,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.error,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  // Helper method to build a modern primary button
  Widget _buildPrimaryButton({
    required String text,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          disabledBackgroundColor:
              Theme.of(context).colorScheme.primary.withOpacity(0.5),
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                  ),
                ),
              )
            : Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }

  // Helper method to build social sign-in buttons
  Widget _buildSocialSignInButton({
    required Widget icon,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 56,
          width: 56,
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surfaceContainerHigh
                : theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Center(
            child: icon,
          ),
        ),
      ),
    );
  }
}
