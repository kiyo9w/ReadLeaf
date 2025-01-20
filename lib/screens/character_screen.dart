import 'dart:io';
import 'package:flutter/material.dart';
import 'package:migrated/models/ai_character.dart';
import 'package:migrated/services/ai_character_service.dart';
import 'package:migrated/depeninject/injection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:path/path.dart' as path;
import 'package:migrated/widgets/ai_character_slider.dart';
import 'package:migrated/screens/home_screen.dart';
import 'package:migrated/utils/utils.dart';

class CharacterScreen extends StatefulWidget {
  const CharacterScreen({super.key});

  @override
  State<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends State<CharacterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _taglineController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _greetingController = TextEditingController();
  String? _selectedImagePath;
  String? _localImagePath;
  String? _selectedVoice;
  bool _isPublic = true;
  int _currentStep = 0;

  final _stepTitles = [
    'Basic Information',
    'Personality',
    'Voice & Settings',
  ];

  final _stepDescriptions = [
    'Enter your character\'s name and choose their appearance',
    'Define your character\'s personality and greeting message',
    'Choose how your character speaks and set visibility',
  ];

  final List<String> _voiceOptions = [
    'Friendly',
    'Professional',
    'Casual',
    'Formal'
  ];

  final ImagePicker _picker = ImagePicker();

  // Custom colors
  static const Color primaryColor = Color(0xFF6750A4);
  static const Color secondaryColor = Color(0xFF9C27B0);
  static const Color backgroundColor = Color(0xFFF8F9FA);
  static const Color surfaceColor = Colors.white;
  static const Color textColor = Color(0xFF1A1A1A);

  void _nextStep() {
    bool canProceed = true;

    switch (_currentStep) {
      case 0:
        canProceed = _nameController.text.isNotEmpty;
        break;
      case 1:
        canProceed = _selectedImagePath != null;
        break;
      case 2:
        canProceed = true;
        break;
      case 3:
        canProceed = _descriptionController.text.isNotEmpty;
        break;
      case 4:
        canProceed = true;
        break;
      case 5:
        canProceed = _selectedVoice != null;
        break;
    }

    if (canProceed) {
      setState(() {
        if (_currentStep < 6) {
          _currentStep++;
        }
      });
    } else {
      Utils.showErrorSnackBar(context, 'Please fill in all required fields');
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  Widget _buildStepContent() {
    final theme = Theme.of(context);
    final steps = [
      _buildBasicInfoStep(),
      _buildPersonalityStep(),
      _buildVoiceStep(),
    ];

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _stepTitles[_currentStep],
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _stepDescriptions[_currentStep],
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            steps[_currentStep],
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoStep() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildImagePicker(),
        const SizedBox(height: 24),
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Character Name',
            hintText: 'Enter a unique name',
            filled: true,
            fillColor: theme.cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(Icons.person_outline),
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
          decoration: InputDecoration(
            labelText: 'Tagline',
            hintText: 'A short description (e.g., "The Wise Mentor")',
            filled: true,
            fillColor: theme.cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(Icons.short_text),
          ),
          validator: (value) {
            if (value?.isEmpty ?? true) {
              return 'Please enter a tagline';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: theme.cardColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.primaryColor.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: _localImagePath != null
                  ? ClipOval(
                      child: Image.file(
                        File(_localImagePath!),
                        fit: BoxFit.cover,
                      ),
                    )
                  : Icon(
                      Icons.add_a_photo_outlined,
                      size: 40,
                      color: theme.primaryColor,
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap to add image',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalityStep() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _descriptionController,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: 'Personality Description',
            hintText:
                'Describe the character\'s personality, traits, and background...',
            filled: true,
            fillColor: theme.cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            alignLabelWithHint: true,
          ),
          validator: (value) {
            if (value?.isEmpty ?? true) {
              return 'Please enter a description';
            }
            return null;
          },
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _greetingController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Greeting Message',
            hintText: 'How should your character introduce themselves?',
            filled: true,
            fillColor: theme.cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            alignLabelWithHint: true,
          ),
          validator: (value) {
            if (value?.isEmpty ?? true) {
              return 'Please enter a greeting';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildVoiceStep() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Voice Style',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildVoiceOption('Friendly', Icons.sentiment_satisfied),
            _buildVoiceOption('Professional', Icons.business),
            _buildVoiceOption('Casual', Icons.coffee),
            _buildVoiceOption('Formal', Icons.school),
          ],
        ),
        const SizedBox(height: 24),
        SwitchListTile(
          title: Text(
            'Public Character',
            style: theme.textTheme.titleMedium,
          ),
          subtitle: Text(
            'Allow others to use this character',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
          ),
          value: _isPublic,
          onChanged: (value) {
            setState(() {
              _isPublic = value;
            });
          },
          activeColor: theme.primaryColor,
        ),
      ],
    );
  }

  Widget _buildVoiceOption(String title, IconData icon) {
    final theme = Theme.of(context);
    final isSelected = _selectedVoice == title;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedVoice = title;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.primaryColor.withOpacity(0.1)
              : theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.primaryColor : theme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? theme.primaryColor : theme.iconTheme.color,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isSelected
                    ? theme.primaryColor
                    : theme.textTheme.bodyMedium?.color,
                fontWeight: isSelected ? FontWeight.bold : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _saveImageToLocal(XFile image) async {
    try {
      final directory = await path_provider.getApplicationDocumentsDirectory();
      final charactersDir = Directory('${directory.path}/characters');
      if (!await charactersDir.exists()) {
        await charactersDir.create(recursive: true);
      }
      final fileName =
          'character_${DateTime.now().millisecondsSinceEpoch}${path.extension(image.path)}';
      final savedImage =
          await File(image.path).copy('${charactersDir.path}/$fileName');
      return savedImage.path;
    } catch (e) {
      Utils.showErrorSnackBar(context, 'Error saving image');
      print('Error saving image: $e');
      return null;
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (image != null) {
        final savedPath = await _saveImageToLocal(image);
        if (savedPath != null) {
          setState(() {
            _selectedImagePath = savedPath;
            _localImagePath = savedPath;
          });
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      Utils.showErrorSnackBar(
          context, 'Failed to pick image. Please try again.');
    }
  }

  String _generatePromptTemplate() {
    return """CHARACTER CONTEXT: You are ${_nameController.text}, ${_descriptionController.text}

ROLEPLAY RULES:
- Chat exclusively as ${_nameController.text}
- Keep responses personal and in-character
- Use subtle physical cues to hint at mental state
- Include internal thoughts in asterisks *like this*
- Keep responses concise (2-3 sentences)
- Stay in character at all times
- Express emotions and reactions naturally
- Use your character's unique way of speaking
- Voice style: $_selectedVoice

CURRENT TASK:
{USER_PROMPT}

CURRENT CONTEXT:
Book: {BOOK_TITLE}
Current Progress: Page {PAGE_NUMBER} of {TOTAL_PAGES} ({PROGRESS}% complete)
Text: {TEXT}""";
  }

  void _createCharacter() async {
    if (_formKey.currentState?.validate() ?? false) {
      final promptTemplate = _generatePromptTemplate();

      final newCharacter = AiCharacter(
        name: _nameController.text,
        imagePath:
            _selectedImagePath ?? 'assets/images/ai_characters/default.png',
        personality: _descriptionController.text,
        trait: _taglineController.text,
        categories: ['Custom'],
        promptTemplate: promptTemplate,
        taskPrompts: {
          'greeting': _greetingController.text,
          'analyze_text': promptTemplate,
          'encouragement': promptTemplate,
        },
      );

      try {
        final aiCharacterService = getIt<AiCharacterService>();
        await aiCharacterService.addCustomCharacter(newCharacter);
        aiCharacterService.setSelectedCharacter(newCharacter);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Character created successfully!'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.green,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );

          AiCharacterSlider.globalKey.currentState?.addCharacter(newCharacter);

          // Reset the form for creating another character
          setState(() {
            _currentStep = 0;
            _nameController.clear();
            _taglineController.clear();
            _descriptionController.clear();
            _greetingController.clear();
            _selectedImagePath = null;
            _localImagePath = null;
            _selectedVoice = null;
            _isPublic = true;
          });
        }
      } catch (e) {
        if (mounted) {
          Utils.showErrorSnackBar(
              context, 'Error creating character: ${e.toString()}');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside of text fields
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.appBarTheme.backgroundColor,
          centerTitle: false,
          title: Text(
            'Create Character',
            style: theme.textTheme.displayLarge,
          ),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildStepIndicator(),
                Expanded(
                  child: _buildStepContent(),
                ),
                _buildNavigationButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            TextButton.icon(
              onPressed: _previousStep,
              icon: Icon(Icons.arrow_back, color: theme.primaryColor),
              label: Text(
                'Back',
                style: TextStyle(
                  color: theme.primaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            const SizedBox.shrink(),
          const Spacer(),
          FilledButton(
            onPressed: _currentStep < 2 ? _nextStep : _createCharacter,
            style: FilledButton.styleFrom(
              backgroundColor: theme.primaryColor,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentStep < 2 ? 'Next' : 'Create',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _currentStep < 2 ? Icons.arrow_forward : Icons.check,
                  size: 20,
                  color: theme.colorScheme.onPrimary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              final isActive = index <= _currentStep;
              final isLast = index == 2;
              return Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive ? theme.primaryColor : theme.cardColor,
                      border: Border.all(
                        color:
                            isActive ? theme.primaryColor : theme.dividerColor,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: isActive
                              ? theme.colorScheme.onPrimary
                              : theme.textTheme.bodyMedium?.color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 40,
                      height: 2,
                      color: isActive ? theme.primaryColor : theme.dividerColor,
                    ),
                ],
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            _stepTitles[_currentStep],
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taglineController.dispose();
    _descriptionController.dispose();
    _greetingController.dispose();
    super.dispose();
  }
}
