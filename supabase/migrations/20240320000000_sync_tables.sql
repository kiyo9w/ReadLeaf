-- Create sync-related tables
CREATE TABLE IF NOT EXISTS public.reading_progress (
    user_id UUID REFERENCES auth.users(id),
    book_id TEXT NOT NULL,
    last_page INTEGER NOT NULL,
    total_pages INTEGER NOT NULL,
    reading_progress FLOAT NOT NULL,
    last_read_time TIMESTAMPTZ NOT NULL,
    highlights JSONB DEFAULT '[]'::jsonb,
    last_synced_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (user_id, book_id)
);

CREATE TABLE IF NOT EXISTS public.character_preferences (
    user_id UUID REFERENCES auth.users(id),
    character_name TEXT NOT NULL,
    last_used TIMESTAMPTZ NOT NULL,
    custom_settings JSONB DEFAULT '{}'::jsonb,
    last_synced_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (user_id, character_name)
);

CREATE TABLE IF NOT EXISTS public.custom_characters (
    user_id UUID REFERENCES auth.users(id),
    name TEXT NOT NULL,
    image_path TEXT NOT NULL,
    personality TEXT NOT NULL,
    prompt_template TEXT NOT NULL,
    task_prompts JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now(),
    last_synced_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (user_id, name)
);

CREATE TABLE IF NOT EXISTS public.chat_history (
    id UUID DEFAULT uuid_generate_v4() NOT NULL,
    user_id UUID REFERENCES auth.users(id),
    character_name TEXT NOT NULL,
    message_text TEXT NOT NULL,
    is_user BOOLEAN NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    book_id TEXT,
    avatar_image_path TEXT,
    sync_status TEXT DEFAULT 'synced',
    sync_version INTEGER DEFAULT 1,
    last_synced_at TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (id),
    UNIQUE (user_id, character_name, timestamp)
);

-- Indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_chat_history_user_character 
ON chat_history (user_id, character_name);

CREATE INDEX IF NOT EXISTS idx_chat_history_timestamp 
ON chat_history (timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_chat_history_sync 
ON chat_history (user_id, sync_status, last_synced_at);

-- Trigger to update timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_chat_history_updated_at
    BEFORE UPDATE ON chat_history
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Enable Row Level Security
ALTER TABLE public.reading_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.character_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.custom_characters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_history ENABLE ROW LEVEL SECURITY;

-- Reading Progress policies
CREATE POLICY "Users can view their own reading progress"
    ON public.reading_progress FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can modify their own reading progress"
    ON public.reading_progress FOR ALL
    USING (auth.uid() = user_id);

-- Character Preferences policies
CREATE POLICY "Users can view their own character preferences"
    ON public.character_preferences FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can modify their own character preferences"
    ON public.character_preferences FOR ALL
    USING (auth.uid() = user_id);

-- Custom Characters policies
CREATE POLICY "Users can view their own custom characters"
    ON public.custom_characters FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can modify their own custom characters"
    ON public.custom_characters FOR ALL
    USING (auth.uid() = user_id);

-- Chat History policies
CREATE POLICY "Users can view their own chat history"
    ON public.chat_history FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can modify their own chat messages"
    ON public.chat_history FOR ALL
    USING (auth.uid() = user_id);

-- Function to handle message cleanup
CREATE OR REPLACE FUNCTION cleanup_old_messages()
RETURNS void AS $$
BEGIN
    -- Keep only the latest 200 messages per user and character
    WITH ranked_messages AS (
        SELECT 
            id,
            ROW_NUMBER() OVER (
                PARTITION BY user_id, character_name 
                ORDER BY timestamp DESC
            ) as rn
        FROM chat_history
    )
    DELETE FROM chat_history
    WHERE id IN (
        SELECT id 
        FROM ranked_messages 
        WHERE rn > 200
    );
END;
$$ LANGUAGE plpgsql;