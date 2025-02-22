# ReadLeaf User Account System Documentation

## Overview
ReadLeaf implements a comprehensive user account system using Supabase as the backend service. The system handles user authentication, profile management, preferences storage, and reading progress synchronization.

## Data Models

### User Model
The core user model (`User`) is implemented using Freezed for immutability and type safety:

```dart
@freezed
class User {
  id: String               // Unique user identifier
  email: String           // User's email address
  username: String        // Display name
  avatarUrl: String?      // Optional profile picture URL
  socialProvider: String? // Authentication provider (Google, Facebook, etc.)
  preferences: UserPreferences
  library: UserLibrary
  aiSettings: UserAISettings
  isAnonymous: bool
  lastSyncTime: DateTime?
}
```

### User Preferences
```dart
@freezed
class UserPreferences {
  darkMode: bool          // Theme preference
  fontSize: String        // Reading font size
  enableAIFeatures: bool  // AI features toggle
  showReadingProgress: bool
  enableAutoSync: bool
  customSettings: Map<String, dynamic>
}
```

### User Library
```dart
@freezed
class UserLibrary {
  filePaths: List<String>          // Stored book paths
  favorites: List<String>          // Favorited books
  lastOpenedPages: Map<String, int> // Reading progress
  bookmarks: Map<String, List<String>>
  lastReadTimes: Map<String, DateTime>
}
```

### User AI Settings
```dart
@freezed
class UserAISettings {
  characterName: String
  customCharacters: List<String>
  enableAutoSummary: bool
  enableContextualInsights: bool
  modelSpecificSettings: Map<String, dynamic>
}
```

## Database Schema

### Tables

#### user_profiles
```sql
CREATE TABLE public.user_profiles (
    id UUID REFERENCES auth.users(id) PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    username TEXT NOT NULL,
    avatar_url TEXT,
    social_provider TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);
```

#### user_preferences
```sql
CREATE TABLE public.user_preferences (
    user_id UUID REFERENCES auth.users(id) PRIMARY KEY,
    dark_mode BOOLEAN DEFAULT false,
    font_size TEXT DEFAULT 'medium',
    enable_ai_features BOOLEAN DEFAULT true,
    show_reading_progress BOOLEAN DEFAULT true,
    enable_auto_sync BOOLEAN DEFAULT false,
    custom_settings JSONB DEFAULT '{}'::jsonb,
    updated_at TIMESTAMPTZ DEFAULT now()
);
```

#### user_library
```sql
CREATE TABLE public.user_library (
    user_id UUID REFERENCES auth.users(id) PRIMARY KEY,
    file_paths TEXT[] DEFAULT '{}',
    favorites TEXT[] DEFAULT '{}',
    last_opened_pages JSONB DEFAULT '{}'::jsonb,
    bookmarks JSONB DEFAULT '{}'::jsonb,
    last_read_times JSONB DEFAULT '{}'::jsonb,
    updated_at TIMESTAMPTZ DEFAULT now()
);
```

#### user_ai_settings
```sql
CREATE TABLE public.user_ai_settings (
    user_id UUID REFERENCES auth.users(id) PRIMARY KEY,
    character_name TEXT DEFAULT '',
    custom_characters TEXT[] DEFAULT '{}',
    enable_auto_summary BOOLEAN DEFAULT true,
    enable_contextual_insights BOOLEAN DEFAULT true,
    model_specific_settings JSONB DEFAULT '{}'::jsonb,
    updated_at TIMESTAMPTZ DEFAULT now()
);
```

## Authentication Flow

### Sign Up Process
1. User enters email, password, and username
2. `AuthBloc` triggers `AuthSignUpRequested` event
3. `SupabaseService.signUp()` is called
4. Supabase creates auth user
5. Database trigger `handle_new_user()` automatically creates:
   - User profile
   - Default preferences
   - Empty library
   - Default AI settings
6. User is automatically signed in
7. UI updates to show authenticated state

### Social Authentication
Supported providers:
- Google (`signInWithGoogle`)
- Facebook (`signInWithFacebook`)

Flow:
1. User clicks social auth button
2. OAuth flow is initiated
3. On success, Supabase creates/updates user
4. Database trigger handles profile creation
5. Social provider avatar is synced if available

### Session Management
- Sessions are handled by Supabase Auth
- `AuthBloc` listens to auth state changes
- Auto-refresh of tokens is handled by Supabase
- Cached state maintained in `AuthBloc._lastKnownState`

## Data Synchronization

### Profile Updates
```dart
Future<void> updateProfile({
  required String userId,
  String? username,
  String? avatarUrl,
}) async {
  final updates = <String, dynamic>{};
  if (username != null) updates['username'] = username;
  if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
  await _client.from('user_profiles').update(updates).eq('id', userId);
}
```

### Preferences Sync
```dart
Future<void> updatePreferences(UserPreferences preferences) async {
  await _client.from('user_preferences').upsert({
    'user_id': userId,
    ...preferences.toJson(),
  });
}
```

### Library Sync
```dart
Future<void> updateLibrary(UserLibrary library) async {
  await _client.from('user_library').upsert({
    'user_id': userId,
    ...library.toJson(),
  });
}
```

## Security

### Row Level Security (RLS)
All tables have RLS policies ensuring users can only:
- Read their own data
- Update their own data
- Never delete data directly

Example policy:
```sql
CREATE POLICY "Users can view their own profile"
    ON public.user_profiles FOR SELECT
    USING (auth.uid() = id);
```

### Data Validation
- Server-side validation through database constraints
- Client-side validation in forms
- Email format validation
- Password requirements:
  - 8 characters minimum
  - 20 characters maximum
  - At least 1 letter and 1 number
  - At least 1 special character

## Error Handling

### Authentication Errors
- Invalid credentials
- Email already in use
- Weak password
- Network errors
- Social auth cancellation

Error display:
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text(error.message),
    backgroundColor: theme.colorScheme.error,
  ),
);
```

## UI Components

### Auth Dialog
- Modal bottom sheet design
- Smooth animations
- Responsive layout
- Dark/light theme support
- Social auth buttons
- Form validation
- Loading states

### Profile Screen
- Avatar management
- Username editing
- Theme toggle
- AI preferences
- Account deletion

## Future Considerations

### Planned Features
- Two-factor authentication
- Password strength meter
- Social account linking
- Enhanced profile customization
- Offline support
- Data export/import

### Scalability
- Current schema supports future extensions
- JSONB fields for flexible storage
- Array fields for list management
- Timestamp tracking for sync conflicts

## Testing

### Unit Tests
- Model serialization
- Auth state management
- Form validation
- Error handling

### Integration Tests
- Auth flow
- Data sync
- Social auth
- Profile updates

### Security Tests
- RLS policy validation
- Input sanitization
- Token handling
- Session management 