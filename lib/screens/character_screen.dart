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

  void _nextStep() {
    bool canProceed = true;

    // Validate current step
    switch (_currentStep) {
      case 0: // Name
        canProceed = _nameController.text.isNotEmpty;
        break;
      case 1: // Photo
        canProceed = _selectedImagePath != null;
        break;
      case 2: // Tagline
        canProceed = true; // Optional
        break;
      case 3: // Description
        canProceed = _descriptionController.text.isNotEmpty;
        break;
      case 4: // Greeting
        canProceed = true; // Optional
        break;
      case 5: // Voice
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'What should we name your character?',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: 'e.g. Albert Einstein',
              border: OutlineInputBorder(),
              labelText: 'Character Name *',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a name';
              }
              return null;
            },
            onChanged: (value) => setState(() {}),
          ),
        ),
      ],
    );
  }

  Future<String?> _saveImageToLocal(XFile image) async {
    try {
      final directory = await path_provider.getApplicationDocumentsDirectory();
      final charactersDir = Directory('${directory.path}/characters');

      // Create the characters directory if it doesn't exist
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
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        // Save image to local storage
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
    }
  }

  Widget _buildImageStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Let's give ${_nameController.text} a photo",
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        if (_selectedImagePath != null)
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey[300]!),
              image: DecorationImage(
                image: _localImagePath != null
                    ? FileImage(File(_localImagePath!)) as ImageProvider
                    : AssetImage(_selectedImagePath!),
                fit: BoxFit.cover,
              ),
            ),
          )
        else
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: const Icon(Icons.person, size: 100, color: Colors.grey),
          ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _pickImage,
          icon: const Icon(Icons.add_photo_alternate),
          label: const Text('Choose Photo *'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        if (_selectedImagePath == null)
          const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Text(
              'Photo is required',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildTaglineStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Give ${_nameController.text} a catchy tagline",
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: TextFormField(
            controller: _taglineController,
            decoration: const InputDecoration(
              hintText: 'Add a short tagline',
              border: OutlineInputBorder(),
            ),
            maxLength: 50,
            onChanged: (value) => setState(() {}),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "How would ${_nameController.text} describe themselves?",
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              hintText: 'Write a description',
              border: OutlineInputBorder(),
              labelText: 'Character Description *',
              helperText: 'Maximum 80 words',
              counterText: '', // Hide the built-in counter
            ),
            maxLength: 500,
            maxLines: 4,
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
            onChanged: (value) {
              final wordCount = value.trim().split(RegExp(r'\s+')).length;
              setState(() {
                // This will trigger a rebuild to update the UI
              });
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${_descriptionController.text.trim().split(RegExp(r'\s+')).length}/80 words',
          style: TextStyle(
            color: _descriptionController.text
                        .trim()
                        .split(RegExp(r'\s+'))
                        .length >
                    80
                ? Colors.red
                : Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildGreetingStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "How should ${_nameController.text} greet others?",
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: TextFormField(
            controller: _greetingController,
            decoration: const InputDecoration(
              hintText:
                  'e.g. Hello, I am Albert. Ask me anything about science!',
              border: OutlineInputBorder(),
            ),
            maxLength: 2048,
            maxLines: 3,
            onChanged: (value) => setState(() {}),
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Choose ${_nameController.text}'s voice style",
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: _voiceOptions
              .map((voice) => ChoiceChip(
                    label: Text(voice),
                    selected: _selectedVoice == voice,
                    onSelected: (selected) {
                      setState(() {
                        _selectedVoice = selected ? voice : null;
                      });
                    },
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildValidationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Review Your Character",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _buildReviewItem("Name", _nameController.text),
          _buildReviewItem("Image", _selectedImagePath ?? "No image selected"),
          _buildReviewItem("Tagline", _taglineController.text),
          _buildReviewItem("Description", _descriptionController.text),
          _buildReviewItem("Greeting", _greetingController.text),
          _buildReviewItem("Voice Style", _selectedVoice ?? "Not selected"),
          const SizedBox(height: 20),
          SwitchListTile(
            title: const Text("Make this character public"),
            value: _isPublic,
            onChanged: (value) => setState(() => _isPublic = value),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(value),
          const Divider(),
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
        // Save character using AiCharacterService (Hive storage)
        final aiCharacterService = getIt<AiCharacterService>();
        await aiCharacterService.addCustomCharacter(newCharacter);

        // Set as current character
        aiCharacterService.setSelectedCharacter(newCharacter);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Character created successfully!'),
              behavior: SnackBarBehavior.floating,
            ),
          );

          // Update the character slider directly
          AiCharacterSlider.globalKey.currentState?.addCharacter(newCharacter);

          // Navigate back
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating character: ${e.toString()}'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(_stepTitles.length, (index) {
          final isActive = index == _currentStep;
          final isCompleted = index < _currentStep;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? const Color(0xFF6750A4) // Purple color from screenshot
                      : Colors.grey[300],
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _stepTitles[index],
                style: TextStyle(
                  fontSize: 14,
                  color: isActive ? const Color(0xFF6750A4) : Colors.grey[600],
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Create Character',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              _buildStepIndicator(),
              const SizedBox(height: 40),
              Expanded(
                child: SingleChildScrollView(
                  child: _buildStepContent(),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentStep > 0)
                        TextButton(
                          onPressed: _previousStep,
                          child: const Text('Back'),
                        )
                      else
                        const SizedBox(width: 80),
                      if (_currentStep < 6)
                        ElevatedButton(
                          onPressed: _nextStep,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6750A4),
                            minimumSize: const Size(120, 48),
                          ),
                          child: const Text(
                            'Next',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        )
                      else
                        ElevatedButton(
                          onPressed: _createCharacter,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            minimumSize: const Size(120, 48),
                          ),
                          child: const Text(
                            'Create',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
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
