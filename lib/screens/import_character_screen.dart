import 'dart:io';
import 'package:flutter/material.dart';
import 'package:read_leaf/models/ai_character.dart';
import 'package:read_leaf/services/ai_character_service.dart';
import 'package:read_leaf/injection.dart';
import 'package:read_leaf/utils/utils.dart';
import 'package:read_leaf/services/character_template_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:read_leaf/blocs/AuthBloc/auth_bloc.dart';
import 'package:read_leaf/blocs/AuthBloc/auth_state.dart';
import 'package:read_leaf/widgets/auth/auth_dialog.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:read_leaf/screens/nav_screen.dart';

class ImportCharacterScreen extends StatefulWidget {
  final String filePath;

  const ImportCharacterScreen({
    super.key,
    required this.filePath,
  });

  @override
  State<ImportCharacterScreen> createState() => _ImportCharacterScreenState();
}

class _ImportCharacterScreenState extends State<ImportCharacterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _taglineController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _greetingController = TextEditingController();
  final _scenarioController = TextEditingController();
  bool _isPublic = true;
  AiCharacter? _importedCharacter;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NavScreen.globalKey.currentState?.hideNavBar(true);
    });
    _loadCharacterData();
  }

  Future<void> _loadCharacterData() async {
    try {
      final characterTemplateService = getIt<CharacterTemplateService>();
      final character =
          await characterTemplateService.importTemplate(widget.filePath);

      setState(() {
        _importedCharacter = character;
        _nameController.text = character.name;
        _taglineController.text = character.tags.join(', ');
        _descriptionController.text = character.personality;
        _greetingController.text = character.greetingMessage;
        _scenarioController.text = character.scenario;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load character data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _importCharacter() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        if (_importedCharacter == null) {
          throw Exception('No character data loaded');
        }

        final authState = context.read<AuthBloc>().state;
        if (authState is! AuthAuthenticated) {
          _showAuthPrompt();
          return;
        }

        final now = DateTime.now();
        final updatedCharacter = _importedCharacter!.copyWith(
          name: _nameController.text,
          tags: _taglineController.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
          personality: _descriptionController.text,
          greetingMessage: _greetingController.text,
          scenario: _scenarioController.text,
          creator: 'User',
          createdAt: now,
          updatedAt: now,
        );

        final aiCharacterService = getIt<AiCharacterService>();
        await aiCharacterService.addCustomCharacter(updatedCharacter);

        if (mounted) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        Utils.showErrorSnackBar(context, 'Error importing character: $e');
      }
    }
  }

  void _showAuthPrompt() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AuthPromptWidget(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Import Character')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Import Character')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Character'),
        actions: [
          TextButton(
            onPressed: _importCharacter,
            child: const Text('Import'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_importedCharacter?.avatarImagePath != null)
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: _importedCharacter!.avatarImagePath
                              .startsWith('http')
                          ? CachedNetworkImage(
                              imageUrl: _importedCharacter!.avatarImagePath,
                              placeholder: (context, url) => Container(
                                color: theme.colorScheme.surfaceContainerHighest,
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: theme.colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.error_outline,
                                  color: theme.colorScheme.error,
                                ),
                              ),
                              fit: BoxFit.cover,
                            )
                          : _importedCharacter!.avatarImagePath
                                  .startsWith('assets/')
                              ? Image.asset(
                                  _importedCharacter!.avatarImagePath,
                                  fit: BoxFit.cover,
                                )
                              : Image.file(
                                  File(_importedCharacter!.avatarImagePath),
                                  fit: BoxFit.cover,
                                ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Character Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _taglineController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Tags (comma-separated)',
                  border: OutlineInputBorder(),
                  helperText: 'Enter tags separated by commas',
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please enter at least one tag';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _scenarioController,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Scenario',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please enter a scenario';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _greetingController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Greeting Message',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please enter a greeting message';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                title: const Text('Public Character'),
                subtitle: const Text('Allow others to use this character'),
                value: _isPublic,
                onChanged: (value) {
                  setState(() {
                    _isPublic = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NavScreen.globalKey.currentState?.hideNavBar(false);
    });
    _nameController.dispose();
    _taglineController.dispose();
    _descriptionController.dispose();
    _greetingController.dispose();
    _scenarioController.dispose();
    super.dispose();
  }
}

class AuthPromptWidget extends StatelessWidget {
  const AuthPromptWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Authentication Required',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'To import and save characters, you need to be signed in. Join our community to unlock all features!',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const AuthDialog(),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Maybe Later',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
