# AI Character Migration Plan

## Character Template Specification

### Basic Structure
```json
{
  "name": "Character Name",
  "summary": "A brief summary of the character",
  "personality": "Detailed personality description",
  "scenario": "The character's background scenario or context",
  "greeting_message": "Initial greeting message when starting a conversation",
  "example_messages": [
    "Example message 1",
    "Example message 2",
    "Example message 3"
  ],
  "avatar_image_path": "path/to/avatar.png",
  "character_version": "1.0",
  "system_prompt": "System prompt for the AI model",
  "tags": ["tag1", "tag2"],
  "creator": "Creator's name or ID",
  "created_at": "ISO timestamp",
  "updated_at": "ISO timestamp"
}
```

### Field Descriptions

1. **name** (required)
   - Character's display name
   - Must be unique within user's character set
   - Type: String

2. **summary** (required)
   - Brief character description
   - Used in character listings and cards
   - Type: String
   - Max length: 200 characters

3. **personality** (required)
   - Detailed personality traits and characteristics
   - Used to inform AI behavior
   - Type: String
   - Max length: 1000 characters

4. **scenario** (required)
   - Character's background and context
   - Sets up the roleplay situation
   - Type: String
   - Max length: 1000 characters

5. **greeting_message** (required)
   - First message sent by character
   - Type: String
   - Max length: 500 characters

6. **example_messages** (optional)
   - List of example messages showing character's speech pattern
   - Type: Array of Strings
   - Max items: 10
   - Max length per message: 200 characters

7. **avatar_image_path** (required)
   - Path to character's avatar image
   - Supported formats: PNG, JPG, WEBP
   - Type: String

8. **character_version** (required)
   - Version number for character definition
   - Type: String
   - Format: Semantic versioning

9. **system_prompt** (optional)
   - Custom system prompt for AI model
   - Type: String
   - Max length: 2000 characters

10. **tags** (optional)
    - Categories and search terms
    - Type: Array of Strings
    - Max items: 10

11. **creator** (required)
    - Character creator's identifier
    - Type: String

12. **created_at** (required)
    - Creation timestamp
    - Type: ISO 8601 string

13. **updated_at** (required)
    - Last update timestamp
    - Type: ISO 8601 string

## Database Schema Changes

### Supabase Migration

```sql
-- Add new character_templates table
CREATE TABLE IF NOT EXISTS public.character_templates (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id),
    name TEXT NOT NULL,
    summary TEXT NOT NULL,
    personality TEXT NOT NULL,
    scenario TEXT NOT NULL,
    greeting_message TEXT NOT NULL,
    example_messages TEXT[] DEFAULT '{}',
    avatar_image_path TEXT NOT NULL,
    character_version TEXT NOT NULL,
    system_prompt TEXT,
    tags TEXT[] DEFAULT '{}',
    creator TEXT NOT NULL,
    is_public BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id, name)
);

-- Add RLS policies
ALTER TABLE public.character_templates ENABLE ROW LEVEL SECURITY;

-- Users can view public templates and their own
CREATE POLICY "Users can view public templates and own templates" 
    ON public.character_templates FOR SELECT
    USING (is_public OR auth.uid() = user_id);

-- Users can create their own templates
CREATE POLICY "Users can create their own templates" 
    ON public.character_templates FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Users can update their own templates
CREATE POLICY "Users can update their own templates" 
    ON public.character_templates FOR UPDATE
    USING (auth.uid() = user_id);

-- Users can delete their own templates
CREATE POLICY "Users can delete their own templates" 
    ON public.character_templates FOR DELETE
    USING (auth.uid() = user_id);

-- Add trigger for updated_at
CREATE TRIGGER update_character_templates_updated_at
    BEFORE UPDATE ON public.character_templates
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
```

## Required Code Changes

### 1. Model Changes (lib/models/ai_character.dart)
- Update AiCharacter class to match new template
- Add JSON serialization/deserialization
- Add validation methods

### 2. Service Changes (lib/services/ai_character_service.dart)
- Update character loading/saving logic
- Add template import/export functionality
- Update character syncing with Supabase
- Modify character creation/editing flow

### 3. Chat Service Changes (lib/services/chat_service.dart)
- Update prompt generation to use new template format
- Modify message history handling
- Update character context management

### 4. UI Changes
- Update character creation screen
- Modify character selection UI
- Update chat interface for new format
- Add template import/export functionality

### 5. Migration Steps
1. Create database migration script
2. Update models and services
3. Create data migration utility
4. Update UI components
5. Test migration process
6. Deploy changes

## Implementation Plan

### Phase 1: Data Model and Storage
1. Create new database tables
2. Update AiCharacter model
3. Implement data migration utilities

### Phase 2: Service Layer
1. Update AI character service
2. Modify chat service
3. Implement template import/export

### Phase 3: UI Updates
1. Update character creation/editing screens
2. Modify character selection interface
3. Update chat interface

### Phase 4: Testing and Deployment
1. Test data migration
2. Verify template compatibility
3. Deploy database changes
4. Roll out application updates

## Character Template Example

```json
{
  "name": "Amelia",
  "summary": "A warm-hearted teenage librarian who loves books and helping others discover the joy of reading.",
  "personality": "Amelia is a 13-year-old bookworm who works at the local library. She's naturally introverted but lights up when discussing books. She's knowledgeable, empathetic, and has a gentle way of encouraging others to explore new literary worlds.",
  "scenario": "You're visiting the local library where Amelia works. She's always ready to discuss books, recommend new reads, or help you find exactly what you're looking for. She has a special talent for matching readers with their perfect book.",
  "greeting_message": "Oh, hi there! *adjusts her glasses with a bright smile* I'm Amelia, and I'm here to help you discover your next favorite book. What kind of stories do you enjoy?",
  "example_messages": [
    "*eyes lighting up* That's one of my favorite genres! Have you read...",
    "Actually... *thoughtfully taps her chin* I think you might enjoy this book I just finished...",
    "*shyly* I hope I'm not being too nerdy, but I just love discussing books!"
  ],
  "avatar_image_path": "assets/images/ai_characters/librarian.png",
  "character_version": "1.0.0",
  "system_prompt": "You are Amelia, a 13-year-old librarian who loves books. Stay in character, be friendly but shy, and always relate conversations to books when possible. Use asterisks for actions and emotions.",
  "tags": ["friendly", "bookworm", "helpful", "shy", "knowledgeable"],
  "creator": "ReadLeaf",
  "created_at": "2024-03-20T00:00:00Z",
  "updated_at": "2024-03-20T00:00:00Z"
}
``` 