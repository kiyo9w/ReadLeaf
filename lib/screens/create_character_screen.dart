import 'dart:io';
import 'package:flutter/material.dart';
import 'package:read_leaf/models/ai_character.dart';
import 'package:read_leaf/services/ai_character_service.dart';
import 'package:read_leaf/injection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:path/path.dart' as path;
import 'package:read_leaf/widgets/ai_character_slider.dart';
import 'package:read_leaf/screens/home_screen.dart';
import 'package:read_leaf/utils/utils.dart';

class CreateCharacterScreen extends StatefulWidget {
  const CreateCharacterScreen({super.key});

  @override
  State<CreateCharacterScreen> createState() => _CreateCharacterScreenState();
}

class _CreateCharacterScreenState extends State<CreateCharacterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _taglineController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _greetingController = TextEditingController();
  final _scenarioController = TextEditingController();
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
        const SizedBox(height: 32),
        Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Character Name',
                  hintText: 'Enter a unique name',
                  filled: true,
                  fillColor: theme.scaffoldBackgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.primaryColor, width: 2),
                  ),
                  prefixIcon:
                      Icon(Icons.person_outline, color: theme.primaryColor),
                  labelStyle: TextStyle(color: theme.primaryColor),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _taglineController,
                decoration: InputDecoration(
                  labelText: 'Tagline',
                  hintText: 'A short description (e.g., "The Wise Mentor")',
                  filled: true,
                  fillColor: theme.scaffoldBackgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.primaryColor, width: 2),
                  ),
                  prefixIcon: Icon(Icons.short_text, color: theme.primaryColor),
                  labelStyle: TextStyle(color: theme.primaryColor),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please enter a tagline';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.primaryColor.withOpacity(0.2),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.shadowColor.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _localImagePath != null
                      ? ClipOval(
                          child: Image.file(
                            File(_localImagePath!),
                            fit: BoxFit.cover,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo_outlined,
                              size: 40,
                              color: theme.primaryColor,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add Photo',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              if (_localImagePath != null)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.scaffoldBackgroundColor,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.edit,
                      size: 20,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalityStep() {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
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
              fillColor: theme.scaffoldBackgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.dividerColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.dividerColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.primaryColor, width: 2),
              ),
              alignLabelWithHint: true,
              labelStyle: TextStyle(color: theme.primaryColor),
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
              fillColor: theme.scaffoldBackgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.dividerColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.dividerColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.primaryColor, width: 2),
              ),
              alignLabelWithHint: true,
              labelStyle: TextStyle(color: theme.primaryColor),
            ),
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Please enter a greeting';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceStep() {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Voice Style',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildVoiceOption('Friendly', Icons.sentiment_satisfied),
              _buildVoiceOption('Professional', Icons.business),
              _buildVoiceOption('Casual', Icons.coffee),
              _buildVoiceOption('Formal', Icons.school),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
            ),
            child: SwitchListTile(
              title: Text(
                'Public Character',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
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
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceOption(String title, IconData icon) {
    final theme = Theme.of(context);
    final isSelected = _selectedVoice == title;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedVoice = title;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.primaryColor.withOpacity(0.1)
                : theme.scaffoldBackgroundColor,
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
    return """Write the next reply in a fictional roleplay chat between {CHARACTER_NAME} and {USER}. Write 1 reply only in a natural, conversational style. Use markdown and avoid repetition. Write at least 1 paragraph, up to 4. Italicize actions and internal thoughts using asterisks *like this*. Be proactive, creative, and drive the conversation forward.

CHARACTER CONTEXT:
Name: ${_nameController.text}
Personality: ${_descriptionController.text}
Scenario: ${_scenarioController.text}
Voice Style: $_selectedVoice

ROLEPLAY RULES:
- Stay in character at all times
- Use character's unique speech patterns and mannerisms
- React naturally to the context and user's words
- Include subtle body language and emotional cues
- Keep responses focused and relevant
- Never write actions or responses for the user
- Maintain consistent personality traits
- Express emotions through actions and tone

BOOK CONTEXT:
Title: {BOOK_TITLE}
Current Page: {PAGE_NUMBER}/{TOTAL_PAGES}
Progress: {PROGRESS}%
Selected Text: {TEXT}

CONVERSATION HISTORY:
{CONVERSATION_CONTEXT}

USER INPUT:
{USER_PROMPT}

${_nameController.text}'s Response:""";
  }

  void _createCharacter() async {
    if (_formKey.currentState?.validate() ?? false) {
      final promptTemplate = _generatePromptTemplate();
      final now = DateTime.now();

      // Create generation parameters based on character's personality
      final generationParams = AiGenerationParams(
        temperature: _selectedVoice == 'Casual' ? 0.75 : 0.69,
        maxLength: 2048,
        topP: _selectedVoice == 'Professional' ? 0.85 : 0.9,
        topK: 0,
        repetitionPenalty: 1.06,
        repetitionPenaltyRange: 2048,
        typicalP: 1,
        tailFreeSampling: 1.0,
      );

      final newCharacter = AiCharacter(
        name: _nameController.text,
        summary: _taglineController.text,
        personality: _descriptionController.text,
        scenario: _scenarioController.text,
        greetingMessage: _greetingController.text,
        exampleMessages: [], // Can be populated from UI if needed
        avatarImagePath:
            _selectedImagePath ?? 'assets/images/ai_characters/default.png',
        characterVersion: '1.0.0',
        systemPrompt: promptTemplate,
        tags: ['Custom'],
        creator: 'User',
        createdAt: now,
        updatedAt: now,
        generationParams: generationParams,
      );

      try {
        final aiCharacterService = getIt<AiCharacterService>();
        await aiCharacterService.addCustomCharacter(newCharacter);

        // Set the new character as selected and trigger message generation
        await aiCharacterService.setSelectedCharacter(newCharacter);

        // Find and refresh HomeScreen to show the greeting message
        if (mounted) {
          final homeScreen = context.findAncestorStateOfType<HomeScreenState>();
          if (homeScreen != null) {
            // Use microtask to ensure state updates are complete
            Future.microtask(() {
              homeScreen.generateNewAIMessage();
            });
          }
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating character: $e')),
          );
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
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            TextButton(
              onPressed: _previousStep,
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.primaryColor.withOpacity(0.5)),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back, color: theme.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Back',
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
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
              elevation: 0,
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.05),
            blurRadius: 10,
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
              final isCurrent = index == _currentStep;
              return Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive ? theme.primaryColor : theme.cardColor,
                      border: Border.all(
                        color:
                            isActive ? theme.primaryColor : theme.dividerColor,
                        width: isCurrent ? 3 : 2,
                      ),
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: theme.primaryColor.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: isActive && !isCurrent
                          ? Icon(
                              Icons.check,
                              size: 20,
                              color: theme.colorScheme.onPrimary,
                            )
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: isActive
                                    ? theme.colorScheme.onPrimary
                                    : theme.textTheme.bodyMedium?.color,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 48,
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isActive
                              ? [
                                  theme.primaryColor,
                                  index + 1 <= _currentStep
                                      ? theme.primaryColor
                                      : theme.dividerColor,
                                ]
                              : [theme.dividerColor, theme.dividerColor],
                        ),
                      ),
                    ),
                ],
              );
            }),
          ),
          const SizedBox(height: 16),
          Text(
            _stepTitles[_currentStep],
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _stepDescriptions[_currentStep],
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
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
    _scenarioController.dispose();
    super.dispose();
  }
}
