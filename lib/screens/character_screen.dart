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

class CharacterScreen extends StatefulWidget {
  const CharacterScreen({super.key});

  @override
  State<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends State<CharacterScreen> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _taglineController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _greetingController = TextEditingController();
  String? _selectedImagePath;
  String? _selectedVoice;
  bool _isPublic = true;

  final List<String> _voiceOptions = [
    'Friendly',
    'Professional',
    'Casual',
    'Formal'
  ];

  final List<String> _stepTitles = [
    'Name',
    'Photo',
    'Tagline',
    'Description',
    'Greeting',
    'Voice',
    'Review'
  ];

  final ImagePicker _picker = ImagePicker();
  String? _localImagePath;

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
      _showErrorSnackBar('Please fill in all required fields');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade800,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  Widget _buildStepContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: _getStepWidget(),
    );
  }

  Widget _getStepWidget() {
    switch (_currentStep) {
      case 0:
        return _buildNameStep();
      case 1:
        return _buildImageStep();
      case 2:
        return _buildTaglineStep();
      case 3:
        return _buildDescriptionStep();
      case 4:
        return _buildGreetingStep();
      case 5:
        return _buildVoiceStep();
      case 6:
        return _buildValidationStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNameStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What should we name your character?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textColor,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Choose a memorable name that reflects their personality',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _nameController,
            style: const TextStyle(fontSize: 18),
            decoration: InputDecoration(
              hintText: 'e.g. Albert Einstein',
              labelText: 'Character Name',
              filled: true,
              fillColor: surfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: primaryColor, width: 2),
              ),
              prefixIcon: const Icon(Icons.person_outline),
              contentPadding: const EdgeInsets.all(20),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a name';
              }
              return null;
            },
            onChanged: (value) => setState(() {}),
          ),
        ],
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
      _showErrorSnackBar('Failed to pick image. Please try again.');
    }
  }

  Widget _buildImageStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Let's give ${_nameController.text} a photo",
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textColor,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Choose a clear, high-quality photo that represents your character',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: surfaceColor,
                  border: Border.all(color: Colors.grey.shade200, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  image: _selectedImagePath != null
                      ? DecorationImage(
                          image: _localImagePath != null
                              ? FileImage(File(_localImagePath!))
                                  as ImageProvider
                              : AssetImage(_selectedImagePath!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _selectedImagePath == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.add_photo_alternate,
                              size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            'Add Photo',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_selectedImagePath == null)
            const Center(
              child: Text(
                'Photo is required',
                style: TextStyle(color: Colors.red, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTaglineStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Give ${_nameController.text} a catchy tagline",
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textColor,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Adjectives that captures their essence',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _taglineController,
            style: const TextStyle(fontSize: 18),
            decoration: InputDecoration(
              hintText: 'e.g. Curious, Funny, Smart...',
              filled: true,
              fillColor: surfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: primaryColor, width: 2),
              ),
              contentPadding: const EdgeInsets.all(20),
            ),
            maxLength: 50,
            onChanged: (value) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "How would ${_nameController.text} describe themselves?",
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textColor,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Write a brief description of their personality and background',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _descriptionController,
            style: const TextStyle(fontSize: 18),
            decoration: InputDecoration(
              hintText: 'Describe your character...',
              filled: true,
              fillColor: surfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: primaryColor, width: 2),
              ),
              contentPadding: const EdgeInsets.all(20),
            ),
            maxLength: 500,
            maxLines: 5,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a description';
              }
              final wordCount = value.trim().split(RegExp(r'\s+')).length;
              if (wordCount > 80) {
                return 'Description should not exceed 80 words';
              }
              return null;
            },
            onChanged: (value) => setState(() {}),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '${_descriptionController.text.trim().split(RegExp(r'\s+')).length}/80 words',
              style: TextStyle(
                color: _descriptionController.text
                            .trim()
                            .split(RegExp(r'\s+'))
                            .length >
                        80
                    ? Colors.red
                    : Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGreetingStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Almost done...",
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            "How should ${_nameController.text} greet others?",
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textColor,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Write a friendly greeting message',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _greetingController,
            style: const TextStyle(fontSize: 18),
            decoration: InputDecoration(
              hintText:
                  'e.g. Hello, I am Albert. Ask me anything about science!',
              filled: true,
              fillColor: surfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: primaryColor, width: 2),
              ),
              contentPadding: const EdgeInsets.all(20),
            ),
            maxLength: 2048,
            maxLines: 3,
            onChanged: (value) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Choose ${_nameController.text}'s voice style",
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textColor,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Select a voice style that matches their personality',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _voiceOptions.map((voice) {
              final isSelected = _selectedVoice == voice;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedVoice = voice;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? primaryColor : surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? primaryColor : Colors.grey.shade200,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    voice,
                    style: TextStyle(
                      color: isSelected ? Colors.white : textColor,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Review Your Character",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textColor,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Make sure everything looks good before creating',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedImagePath != null)
                  Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: _localImagePath != null
                              ? FileImage(File(_localImagePath!))
                              : AssetImage(_selectedImagePath!)
                                  as ImageProvider,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                _buildReviewItem("Name", _nameController.text),
                _buildReviewItem("Tagline", _taglineController.text),
                _buildReviewItem("Description", _descriptionController.text),
                _buildReviewItem("Greeting", _greetingController.text),
                _buildReviewItem(
                    "Voice Style", _selectedVoice ?? "Not selected"),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text(
                    "Make this character public",
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                  value: _isPublic,
                  onChanged: (value) => setState(() => _isPublic = value),
                  activeColor: primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? "Not set" : value,
            style: TextStyle(
              fontSize: 16,
              color: value.isEmpty ? Colors.grey : textColor,
            ),
          ),
          const Divider(height: 24),
        ],
      ),
    );
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
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackBar('Error creating character: ${e.toString()}');
        }
      }
    }
  }

  Widget _buildStepIndicator() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _stepTitles.length,
        itemBuilder: (context, index) {
          final isActive = index == _currentStep;
          final isCompleted = index < _currentStep;

          return Container(
            width: 80,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? primaryColor
                        : isCompleted
                            ? primaryColor.withOpacity(0.2)
                            : Colors.grey.shade200,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(
                            Icons.check,
                            size: 16,
                            color: primaryColor,
                          )
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isActive ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _stepTitles[index],
                  style: TextStyle(
                    fontSize: 12,
                    color: isActive ? primaryColor : Colors.grey,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_currentStep > 0)
              TextButton.icon(
                onPressed: _previousStep,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              )
            else
              const SizedBox(width: 100),
            if (_currentStep < 6)
              ElevatedButton(
                onPressed: _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
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
                  children: const [
                    Text(
                      'Next',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 20, color: Colors.white),
                  ],
                ),
              )
            else
              ElevatedButton(
                onPressed: _createCharacter,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
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
                  children: const [
                    Text(
                      'Create',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.check, size: 20, color: Colors.white),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        title: Text(
          'Create Character',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
          color: textColor,
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
