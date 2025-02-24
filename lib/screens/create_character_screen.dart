import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:path/path.dart' as path;
import 'package:read_leaf/models/ai_character.dart';
import 'package:read_leaf/services/ai_character_service.dart';
import 'package:read_leaf/injection.dart';
import 'package:read_leaf/screens/home_screen.dart';
import 'package:read_leaf/utils/utils.dart';
import 'package:read_leaf/constants/responsive_constants.dart';
import 'package:read_leaf/services/character_suggestion_service.dart';
import 'package:read_leaf/widgets/character_suggestion_chips.dart';

class CreateCharacterScreen extends StatefulWidget {
  const CreateCharacterScreen({super.key});

  @override
  State<CreateCharacterScreen> createState() => _CreateCharacterScreenState();
}

class _CreateCharacterScreenState extends State<CreateCharacterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();

  final _nameController = TextEditingController();
  final _taglineController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _greetingController = TextEditingController();
  final _scenarioController = TextEditingController();

  String? _selectedImagePath;
  String? _localImagePath;
  final List<String> _selectedTags = [];
  String? _selectedVoice;
  bool _isPublic = true;
  int _currentStep = 0;
  final List<String> _selectedTraits = [];
  final Map<String, String> _tagToText = {}; // maps trait to text

  // Focus nodes for form fields
  final _descriptionFocusNode = FocusNode();
  final _greetingFocusNode = FocusNode();
  final _scenarioFocusNode = FocusNode();
  final _taglineFocusNode = FocusNode();
  final _tagsFocusNode = FocusNode();

  // For contextual suggestions (if needed)
  String? _selectedContext;
  bool _showTagSuggestions = false;
  bool _showScenarioSuggestions = false;
  bool _showGreetingSuggestions = false;
  bool _showTaglineSuggestions = false;
  List<String> _currentSuggestions = [];

  // Step titles and descriptions
  final _stepTitles = [
    'Basic Information',
    'Traits',
    'Voice & Settings',
  ];
  final _stepDescriptions = [
    'Enter your character\'s name and choose their appearance',
    'Select traits from multiple categories',
    'Choose how your character speaks and set visibility',
  ];

  // Voice options
  final _voiceOptions = ['Friendly', 'Professional', 'Casual', 'Formal'];

  final ImagePicker _picker = ImagePicker();

  // For multi-category chips, we load categories from JSON
  Map<String, List<String>> _categoryTraits = {};
  Map<String, List<String>> _relatedTraits = {};

  @override
  void initState() {
    super.initState();
    _setupFocusListeners();
    _loadTraitData();
  }

  // Load trait data from JSON and extract category information
  Future<void> _loadTraitData() async {
    try {
      final jsonString = await DefaultAssetBundle.of(context)
          .loadString('lib/data/personality_traits.json');
      final data = json.decode(jsonString);

      // Using the "trait_categories" field
      final Map<String, dynamic> traitCats = data['trait_categories'];
      Map<String, List<String>> catMap = {};
      traitCats.forEach((category, list) {
        // Remove duplicate traits if needed.
        catMap[category] = List<String>.from(list.toSet());
      });

      // For related traits, we use the existing field
      final Map<String, dynamic> relMap = data['trait_relationships'];
      Map<String, List<String>> related = {};
      relMap.forEach((key, value) {
        // Convert the Map<String, double> to List<String> by taking the keys
        final Map<String, dynamic> relations = value as Map<String, dynamic>;
        related[key] = relations.keys.toList();
      });

      setState(() {
        _categoryTraits = catMap;
        _relatedTraits = related;
      });
    } catch (e) {
      print('Error loading trait data: $e');
    }
  }

  void _setupFocusListeners() {
    _tagsFocusNode.addListener(() {
      setState(() {
        _showTagSuggestions = _tagsFocusNode.hasFocus;
        if (_showTagSuggestions) {
          _currentSuggestions =
              CharacterSuggestionService.getFilteredSuggestions(
            'tags',
            _selectedTraits,
          );
        }
      });
    });
    _taglineFocusNode.addListener(() {
      setState(() {
        _showTaglineSuggestions = _taglineFocusNode.hasFocus;
        if (_showTaglineSuggestions) _updateTaglineSuggestions();
      });
    });
    _greetingFocusNode.addListener(() {
      setState(() {
        _showGreetingSuggestions = _greetingFocusNode.hasFocus;
        if (_showGreetingSuggestions) _updateGreetingSuggestions();
      });
    });
    _scenarioFocusNode.addListener(() {
      setState(() {
        _showScenarioSuggestions = _scenarioFocusNode.hasFocus;
        if (_showScenarioSuggestions) _updateScenarioSuggestions();
      });
    });
    _descriptionController.addListener(() {
      if (_descriptionFocusNode.hasFocus) _onDescriptionChanged();
    });
  }

  void _onTagSelected(String tag) {
    setState(() {
      if (!_selectedTraits.contains(tag)) {
        _selectedTraits.add(tag);
        final currentText = _descriptionController.text;
        final newText = currentText.isEmpty ? tag : '$currentText, $tag';
        _descriptionController.text = newText;
        _tagToText[tag] = tag;
        _descriptionController.selection = TextSelection.fromPosition(
          TextPosition(offset: _descriptionController.text.length),
        );
        _updateTaglineSuggestions();
        _updateGreetingSuggestions();
        _updateScenarioSuggestions();
      }
    });
  }

  void _onTagDeleted(String tag) {
    setState(() {
      _selectedTraits.remove(tag);
      _currentSuggestions = CharacterSuggestionService.getFilteredSuggestions(
        'tags',
        _selectedTraits,
      );
    });
  }

  void _updateTaglineSuggestions() {
    if (_selectedTraits.isEmpty) return;
    final suggestions =
        CharacterSuggestionService.getTaglineSuggestions(_selectedTraits);
    setState(() {
      _showTaglineSuggestions =
          _taglineFocusNode.hasFocus && suggestions.isNotEmpty;
      _currentSuggestions = suggestions;
    });
  }

  void _updateGreetingSuggestions() {
    if (_selectedTraits.isEmpty) return;
    final suggestions = CharacterSuggestionService.getGreetingSuggestions(
      _selectedTraits,
      _selectedContext,
    );
    setState(() {
      _showGreetingSuggestions =
          _greetingFocusNode.hasFocus && suggestions.isNotEmpty;
      _currentSuggestions = suggestions;
    });
  }

  void _updateScenarioSuggestions() {
    if (_selectedTraits.isEmpty) return;
    final suggestions = CharacterSuggestionService.getScenarioSuggestions(
      _selectedTraits,
      _selectedContext,
    );
    setState(() {
      _showScenarioSuggestions =
          _scenarioFocusNode.hasFocus && suggestions.isNotEmpty;
      _currentSuggestions = suggestions;
    });
  }

  void _updateSuggestionsBasedOnContext() {
    if (_selectedContext != null) {
      final contextualGreetings =
          CharacterSuggestionService.getContextualGreetings(
        _selectedTraits,
        _selectedContext!,
      );
      if (contextualGreetings.isNotEmpty) {
        _greetingController.text = contextualGreetings.values.first;
      }
      final contextualScenarios =
          CharacterSuggestionService.getContextualScenarios(
        _selectedTraits,
        _selectedContext!,
      );
      if (contextualScenarios.isNotEmpty) {
        _scenarioController.text = contextualScenarios.values.first;
      }
    }
  }

  void _onDescriptionChanged() {
    final currentText = _descriptionController.text;
    for (final tag in _tagToText.keys.toList()) {
      if (!currentText.contains(_tagToText[tag]!)) {
        setState(() {
          _selectedTraits.remove(tag);
          _tagToText.remove(tag);
        });
      }
    }
    if (currentText.isEmpty) {
      setState(() {
        _selectedTraits.clear();
        _tagToText.clear();
        _showTagSuggestions = true;
      });
    }
  }

  // -------------------- UI Building --------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = ResponsiveConstants.isTablet(context);
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text('Create Character',
              style: theme.textTheme.displayLarge?.copyWith(
                fontSize: isTablet ? 28 : 24,
              )),
          centerTitle: false,
        ),
        body: SafeArea(
          child: SizedBox.expand(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildStepIndicator(),
                  Expanded(child: _buildStepContent(isTablet)),
                  _buildNavigationButtons(isTablet),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final theme = Theme.of(context);
    final isTablet = ResponsiveConstants.isTablet(context);
    return Column(
      children: [
        LinearProgressIndicator(
          value: (_currentStep + 1) / 3,
          backgroundColor: theme.dividerColor,
          color: theme.primaryColor,
          minHeight: isTablet ? 8 : 4,
        ),
        const SizedBox(height: 12),
        Text(
          _stepTitles[_currentStep],
          style: theme.textTheme.headlineSmall?.copyWith(
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
    );
  }

  Widget _buildStepContent(bool isTablet) {
    return PageView(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildBasicInfoStep(isTablet),
        _buildTraitSelectionStep(isTablet),
        _buildVoiceStep(isTablet),
      ],
    );
  }

  Widget _buildBasicInfoStep(bool isTablet) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.all(isTablet ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildImagePicker(isTablet),
          const SizedBox(height: 24),
          TextFormField(
            controller: _nameController,
            style: TextStyle(fontSize: isTablet ? 16 : 14),
            decoration: InputDecoration(
              labelText: 'Character Name',
              hintText: 'Enter a unique name',
              filled: true,
              fillColor: theme.scaffoldBackgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
              ),
              prefixIcon: Icon(Icons.person_outline,
                  color: theme.primaryColor, size: isTablet ? 24 : 20),
            ),
            validator: (value) =>
                (value?.isEmpty ?? true) ? 'Please enter a name' : null,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _taglineController,
            style: TextStyle(fontSize: isTablet ? 16 : 14),
            decoration: InputDecoration(
              labelText: 'Tagline',
              hintText: 'A short description (e.g., "The Wise Mentor")',
              filled: true,
              fillColor: theme.scaffoldBackgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
              ),
              prefixIcon: Icon(Icons.short_text,
                  color: theme.primaryColor, size: isTablet ? 24 : 20),
            ),
            validator: (value) =>
                (value?.isEmpty ?? true) ? 'Please enter a tagline' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker(bool isTablet) {
    final theme = Theme.of(context);
    return Center(
      child: Stack(
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: isTablet ? 180 : 140,
              height: isTablet ? 180 : 140,
              decoration: BoxDecoration(
                color: theme.cardColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.primaryColor.withOpacity(0.2),
                  width: isTablet ? 4 : 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withOpacity(0.1),
                    blurRadius: isTablet ? 12 : 10,
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
                        Icon(Icons.add_a_photo_outlined,
                            size: isTablet ? 48 : 40,
                            color: theme.primaryColor),
                        const SizedBox(height: 8),
                        Text('Add Photo',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.primaryColor,
                              fontWeight: FontWeight.w500,
                            )),
                      ],
                    ),
            ),
          ),
          if (_localImagePath != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.all(isTablet ? 6 : 4),
                height: isTablet ? 48 : 40,
                width: isTablet ? 48 : 40,
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.scaffoldBackgroundColor,
                    width: isTablet ? 3 : 2,
                  ),
                ),
                child: IconButton(
                  onPressed: _pickImage,
                  icon: Icon(Icons.edit,
                      color: theme.colorScheme.onPrimary,
                      size: isTablet ? 24 : 22),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ------------------ New Trait Selection Step ------------------
  Widget _buildTraitSelectionStep(bool isTablet) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Character Traits',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          // Use the new multi-category chip widget
          MultiCategorySuggestionChips(
            categoryTraits: _categoryTraits,
            relatedTraits: _relatedTraits,
            selectedTraits: _selectedTraits.toSet(),
            onChipSelected: _onTagSelected,
            enableSearch: true,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _descriptionController,
            focusNode: _descriptionFocusNode,
            maxLines: 5,
            onChanged: (text) => _onDescriptionChanged(),
            style: TextStyle(fontSize: isTablet ? 16 : 14),
            decoration: InputDecoration(
              labelText: 'Personality Description',
              hintText:
                  'Select traits to build your character\'s personality...',
              filled: true,
              fillColor: theme.scaffoldBackgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
              ),
            ),
            validator: (value) =>
                (value?.isEmpty ?? true) ? 'Please enter a description' : null,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _taglineController,
            focusNode: _taglineFocusNode,
            style: TextStyle(fontSize: isTablet ? 16 : 14),
            decoration: InputDecoration(
              labelText: 'Tagline',
              hintText: 'A short description (e.g., "The Wise Mentor")',
              filled: true,
              fillColor: theme.scaffoldBackgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
              ),
              prefixIcon: Icon(Icons.short_text,
                  color: theme.primaryColor, size: isTablet ? 24 : 20),
            ),
          ),
          // Optionally, add contextual suggestion chips here if needed
          const SizedBox(height: 24),
          TextFormField(
            controller: _scenarioController,
            focusNode: _scenarioFocusNode,
            maxLines: 3,
            style: TextStyle(fontSize: isTablet ? 16 : 14),
            decoration: InputDecoration(
              labelText: 'Scenario',
              hintText:
                  'Describe the setting and context for your character...',
              filled: true,
              fillColor: theme.scaffoldBackgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _greetingController,
            focusNode: _greetingFocusNode,
            maxLines: 3,
            style: TextStyle(fontSize: isTablet ? 16 : 14),
            decoration: InputDecoration(
              labelText: 'Greeting Message',
              hintText: 'How should your character introduce themselves?',
              filled: true,
              fillColor: theme.scaffoldBackgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
  // ------------------ End Trait Selection Step ------------------

  Widget _buildVoiceStep(bool isTablet) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Voice Style',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
              fontSize: isTablet ? 20 : 18,
            ),
          ),
          SizedBox(height: isTablet ? 20 : 16),
          Wrap(
            spacing: isTablet ? 16 : 12,
            runSpacing: isTablet ? 16 : 12,
            children: _voiceOptions
                .map((option) => _buildVoiceOption(option, isTablet))
                .toList(),
          ),
          SizedBox(height: isTablet ? 28 : 24),
          Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
              border: Border.all(color: theme.dividerColor),
            ),
            child: SwitchListTile(
              title: Text(
                'Public Character',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: isTablet ? 18 : 16,
                ),
              ),
              subtitle: Text(
                'Allow others to use this character',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                  fontSize: isTablet ? 14 : 12,
                ),
              ),
              value: _isPublic,
              onChanged: (value) => setState(() => _isPublic = value),
              activeColor: theme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceOption(String title, bool isTablet) {
    final theme = Theme.of(context);
    final isSelected = _selectedVoice == title;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedVoice = title),
        borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 20 : 16, vertical: isTablet ? 16 : 12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.primaryColor.withOpacity(0.1)
                : theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
            border: Border.all(
              color: isSelected ? theme.primaryColor : theme.dividerColor,
              width: isSelected ? (isTablet ? 2.5 : 2) : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                title == 'Friendly'
                    ? Icons.sentiment_satisfied
                    : title == 'Professional'
                        ? Icons.business
                        : title == 'Casual'
                            ? Icons.coffee
                            : Icons.school,
                color: isSelected ? theme.primaryColor : theme.iconTheme.color,
                size: isTablet ? 24 : 20,
              ),
              SizedBox(width: isTablet ? 12 : 8),
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isSelected
                      ? theme.primaryColor
                      : theme.textTheme.bodyMedium?.color,
                  fontWeight: isSelected ? FontWeight.bold : null,
                  fontSize: isTablet ? 16 : 14,
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
        exampleMessages: [],
        avatarImagePath:
            _selectedImagePath ?? 'assets/images/ai_characters/default.png',
        characterVersion: '1.0.0',
        systemPrompt: promptTemplate,
        tags: [..._selectedTags, 'Custom'],
        creator: 'User',
        createdAt: now,
        updatedAt: now,
        generationParams: generationParams,
      );

      try {
        final aiCharacterService = getIt<AiCharacterService>();
        await aiCharacterService.addCustomCharacter(newCharacter);
        await aiCharacterService.setSelectedCharacter(newCharacter);
        if (mounted) {
          final homeScreen = context.findAncestorStateOfType<HomeScreenState>();
          if (homeScreen != null) {
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

  void _nextStep() {
    if (_formKey.currentState?.validate() ?? false) {
      if (_currentStep < 2) {
        setState(() {
          _currentStep++;
          _pageController.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut);
        });
      } else {
        _createCharacter();
      }
    } else {
      Utils.showErrorSnackBar(context, 'Please fill in all required fields');
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _pageController.previousPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut);
      });
    }
  }

  Widget _buildNavigationButtons(bool isTablet) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
              color: theme.shadowColor.withOpacity(0.1),
              blurRadius: isTablet ? 12 : 10,
              offset: const Offset(0, -4))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            TextButton(
              onPressed: _previousStep,
              child: Row(
                children: [
                  Icon(Icons.arrow_back,
                      color: theme.primaryColor, size: isTablet ? 24 : 20),
                  SizedBox(width: isTablet ? 12 : 8),
                  Text('Back',
                      style: TextStyle(
                          color: theme.primaryColor,
                          fontSize: isTablet ? 18 : 16,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            )
          else
            const SizedBox.shrink(),
          const Spacer(),
          FilledButton(
            onPressed: _nextStep,
            style: FilledButton.styleFrom(
              backgroundColor: theme.primaryColor,
              padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 36 : 32, vertical: isTablet ? 16 : 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
              ),
              elevation: 0,
            ),
            child: Row(
              children: [
                Text(_currentStep < 2 ? 'Next' : 'Create',
                    style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontSize: isTablet ? 18 : 16,
                        fontWeight: FontWeight.bold)),
                SizedBox(width: isTablet ? 12 : 8),
                Icon(_currentStep < 2 ? Icons.arrow_forward : Icons.check,
                    size: isTablet ? 24 : 20,
                    color: theme.colorScheme.onPrimary),
              ],
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
    _scenarioController.dispose();
    _descriptionFocusNode.dispose();
    _greetingFocusNode.dispose();
    _scenarioFocusNode.dispose();
    _taglineFocusNode.dispose();
    _tagsFocusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }
}
