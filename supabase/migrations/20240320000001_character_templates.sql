-- Create character templates table
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

-- Add migration function to convert existing characters
CREATE OR REPLACE FUNCTION migrate_existing_characters()
RETURNS void AS $$
DECLARE
    user_record RECORD;
    custom_chars TEXT[];
BEGIN
    -- Loop through each user with custom characters
    FOR user_record IN 
        SELECT id, custom_characters 
        FROM public.user_ai_settings 
        WHERE custom_characters IS NOT NULL AND array_length(custom_characters, 1) > 0
    LOOP
        custom_chars := user_record.custom_characters;
        
        -- For each custom character, create a template
        FOR i IN 1..array_length(custom_chars, 1) LOOP
            -- Parse the character data (assuming JSON format)
            -- Note: This is a simplified version, adjust based on actual data structure
            INSERT INTO public.character_templates (
                user_id,
                name,
                summary,
                personality,
                scenario,
                greeting_message,
                avatar_image_path,
                character_version,
                creator,
                is_public
            )
            VALUES (
                user_record.id,
                custom_chars[i]->>'name',
                COALESCE(custom_chars[i]->>'trait', 'A custom AI character'),
                custom_chars[i]->>'personality',
                'Default scenario for migrated character',
                COALESCE(custom_chars[i]->'taskPrompts'->>'greeting', 'Hello! Nice to meet you.'),
                COALESCE(custom_chars[i]->>'imagePath', 'assets/images/ai_characters/default.png'),
                '1.0.0',
                'System Migration',
                false
            )
            ON CONFLICT (user_id, name) DO NOTHING;
        END LOOP;
    END LOOP;
END;
$$ LANGUAGE plpgsql; 