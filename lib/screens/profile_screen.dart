import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get_it/get_it.dart';
import '../blocs/AuthBloc/auth_bloc.dart';
import '../blocs/AuthBloc/auth_event.dart';
import '../blocs/AuthBloc/auth_state.dart';
import '../services/image_service.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../widgets/auth/auth_text_field.dart';
import '../widgets/auth/auth_button.dart';
import '../models/user.dart' as app_models;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  late final ImageService _imageService;
  late final StorageService _storageService;
  bool _isEditing = false;
  bool _isLoading = false;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    final state = context.read<AuthBloc>().state;
    if (state is AuthAuthenticated) {
      _usernameController = TextEditingController(text: state.user.username);
    } else {
      _usernameController = TextEditingController();
    }
    _imageService = GetIt.I<ImageService>();
    _storageService = GetIt.I<StorageService>();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await _imageService.pickAndCropImage(
      source: ImageSource.gallery,
      aspectRatio: 1,
    );

    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final state = context.read<AuthBloc>().state;
      if (state is! AuthAuthenticated) {
        throw Exception('Not authenticated');
      }

      String? avatarUrl;
      if (_selectedImage != null) {
        avatarUrl = await _storageService.uploadProfilePicture(
          _selectedImage!,
          state.user.id,
        );

        if (avatarUrl == null) {
          throw Exception('Failed to upload profile picture');
        }
      }

      // Update profile in Supabase
      await GetIt.I<SupabaseService>().updateProfile(
        userId: state.user.id,
        username: _usernameController.text.trim(),
        avatarUrl: avatarUrl ?? state.user.avatarUrl,
      );

      // Refresh the auth state to update the UI
      if (mounted) {
        context.read<AuthBloc>().add(AuthCheckRequested());
      }

      setState(() {
        _isEditing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resetPassword() async {
    final state = context.read<AuthBloc>().state;
    if (state is! AuthAuthenticated) return;

    try {
      // TODO: Implement password reset
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final state = context.read<AuthBloc>().state;
      if (state is! AuthAuthenticated) return;

      // Delete profile picture if exists
      await _storageService.deleteProfilePicture(state.user.id);

      // TODO: Delete user account from Supabase
      context.read<AuthBloc>().add(AuthSignOutRequested());
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        // Keep showing the current UI while loading
        if (state is AuthLoading && _isLoading) {
          // Don't show loading screen during profile update
          return _buildProfileContent(
              context, (context.read<AuthBloc>().state as AuthAuthenticated));
        }

        if (state is! AuthAuthenticated) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return _buildProfileContent(context, state);
      },
    );
  }

  Widget _buildProfileContent(BuildContext context, AuthAuthenticated state) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (_isEditing)
            IconButton(
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _usernameController.text = state.user.username;
                  _selectedImage = null;
                });
              },
              icon: const Icon(Icons.close),
            )
          else
            IconButton(
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              icon: const Icon(Icons.edit),
            ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: _getAvatarImage(state.user),
                          child: _shouldShowDefaultIcon(state.user)
                              ? const Icon(Icons.person, size: 50)
                              : null,
                        ),
                        if (_isEditing)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  AuthTextField(
                    controller: _usernameController,
                    labelText: 'Username',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a username';
                      }
                      return null;
                    },
                    enabled: _isEditing,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.user.email,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (_isEditing) ...[
                    AuthButton(
                      text: 'Save Changes',
                      onPressed: _updateProfile,
                      isLoading: _isLoading,
                    ),
                    const SizedBox(height: 16),
                  ],
                  AuthButton(
                    text: 'Reset Password',
                    onPressed: _resetPassword,
                    isOutlined: true,
                    icon: Icons.lock_reset,
                  ),
                  const SizedBox(height: 16),
                  AuthButton(
                    text: 'Sign Out',
                    onPressed: () {
                      context.read<AuthBloc>().add(AuthSignOutRequested());
                      Navigator.of(context).pop();
                    },
                    isOutlined: true,
                    icon: Icons.logout,
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: _deleteAccount,
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    child: const Text('Delete Account'),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  ImageProvider? _getAvatarImage(app_models.User user) {
    if (_selectedImage != null) {
      return FileImage(_selectedImage!);
    }
    if (user.avatarUrl != null) {
      return NetworkImage(user.avatarUrl!);
    }
    return null;
  }

  bool _shouldShowDefaultIcon(app_models.User user) {
    return _selectedImage == null && user.avatarUrl == null;
  }
}
