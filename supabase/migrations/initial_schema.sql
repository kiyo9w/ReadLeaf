-- Create tables for user data
CREATE TABLE IF NOT EXISTS public.user_profiles (
    id UUID REFERENCES auth.users(id) PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    username TEXT NOT NULL,
    avatar_url TEXT,
    social_provider TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- User preferences table
CREATE TABLE IF NOT EXISTS public.user_preferences (
    user_id UUID REFERENCES auth.users(id) PRIMARY KEY,
    dark_mode BOOLEAN DEFAULT false,
    font_size TEXT DEFAULT 'medium',
    enable_ai_features BOOLEAN DEFAULT true,
    show_reading_progress BOOLEAN DEFAULT true,
    enable_auto_sync BOOLEAN DEFAULT false,
    custom_settings JSONB DEFAULT '{}'::jsonb,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- User library table
CREATE TABLE IF NOT EXISTS public.user_library (
    user_id UUID REFERENCES auth.users(id) PRIMARY KEY,
    file_paths TEXT[] DEFAULT '{}',
    favorites TEXT[] DEFAULT '{}',
    last_opened_pages JSONB DEFAULT '{}'::jsonb,
    bookmarks JSONB DEFAULT '{}'::jsonb,
    last_read_times JSONB DEFAULT '{}'::jsonb,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- User AI settings table
CREATE TABLE IF NOT EXISTS public.user_ai_settings (
    user_id UUID REFERENCES auth.users(id) PRIMARY KEY,
    character_name TEXT DEFAULT '',
    custom_characters TEXT[] DEFAULT '{}',
    enable_auto_summary BOOLEAN DEFAULT true,
    enable_contextual_insights BOOLEAN DEFAULT true,
    model_specific_settings JSONB DEFAULT '{}'::jsonb,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Row Level Security (RLS) policies
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_library ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_ai_settings ENABLE ROW LEVEL SECURITY;

-- Policies for user_profiles
CREATE POLICY "Users can insert their own profile"
    ON public.user_profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can view their own profile"
    ON public.user_profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
    ON public.user_profiles FOR UPDATE
    USING (auth.uid() = id);

-- Policies for user_preferences
CREATE POLICY "Users can insert their own preferences"
    ON public.user_preferences FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view their own preferences"
    ON public.user_preferences FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own preferences"
    ON public.user_preferences FOR UPDATE
    USING (auth.uid() = user_id);

-- Policies for user_library
CREATE POLICY "Users can insert their own library"
    ON public.user_library FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view their own library"
    ON public.user_library FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own library"
    ON public.user_library FOR UPDATE
    USING (auth.uid() = user_id);

-- Policies for user_ai_settings
CREATE POLICY "Users can insert their own AI settings"
    ON public.user_ai_settings FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view their own AI settings"
    ON public.user_ai_settings FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own AI settings"
    ON public.user_ai_settings FOR UPDATE
    USING (auth.uid() = user_id);

-- Create a function to handle new user registration
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  username_from_metadata TEXT;
  avatar_from_metadata TEXT;
  provider_from_metadata TEXT;
BEGIN
  -- Get username from metadata, fallback to email username part if not available
  username_from_metadata := COALESCE(
    new.raw_user_meta_data->>'name',
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'username',
    SPLIT_PART(new.email, '@', 1)
  );

  -- Get avatar URL from metadata
  avatar_from_metadata := COALESCE(
    new.raw_user_meta_data->>'avatar_url',
    new.raw_user_meta_data->>'picture'
  );

  -- Get provider from metadata
  provider_from_metadata := new.raw_user_meta_data->>'provider';
  
  -- Insert user profile
  INSERT INTO public.user_profiles (id, email, username, avatar_url, social_provider)
  VALUES (
    new.id,
    new.email,
    username_from_metadata,
    avatar_from_metadata,
    provider_from_metadata
  );
  
  -- Insert default preferences
  INSERT INTO public.user_preferences (user_id)
  VALUES (new.id);
  
  -- Insert empty library
  INSERT INTO public.user_library (user_id)
  VALUES (new.id);
  
  -- Insert default AI settings
  INSERT INTO public.user_ai_settings (user_id)
  VALUES (new.id);
  
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Functions for automatic timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for updating timestamps
CREATE TRIGGER update_user_profiles_updated_at
    BEFORE UPDATE ON public.user_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_preferences_updated_at
    BEFORE UPDATE ON public.user_preferences
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_library_updated_at
    BEFORE UPDATE ON public.user_library
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_ai_settings_updated_at
    BEFORE UPDATE ON public.user_ai_settings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column(); 