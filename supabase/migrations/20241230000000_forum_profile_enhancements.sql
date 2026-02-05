-- Forum Setup & Profile Enhancements Migration
-- ============================================================
-- 1. Forum Categories
-- 2. Profile columns (post_count, is_admin)
-- 3. Post count triggers
-- 4. Wiki suggestions table
-- ============================================================

-- ============================================================
-- FORUM CATEGORIES
-- ============================================================
-- Note: Column names may need adjustment based on actual schema
-- The code uses icon_name and display_order but schema.sql shows icon and sort_order
-- Adding IF NOT EXISTS for column renames to handle either state

-- Ensure icon_name column exists (in case schema still has 'icon')
DO $$
BEGIN
  -- Rename icon to icon_name if icon exists and icon_name doesn't
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'forum_categories' AND column_name = 'icon')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'forum_categories' AND column_name = 'icon_name') THEN
    ALTER TABLE public.forum_categories RENAME COLUMN icon TO icon_name;
  END IF;

  -- Rename sort_order to display_order if sort_order exists and display_order doesn't
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'forum_categories' AND column_name = 'sort_order')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'forum_categories' AND column_name = 'display_order') THEN
    ALTER TABLE public.forum_categories RENAME COLUMN sort_order TO display_order;
  END IF;
END $$;
-- Clear existing categories and insert the 8 required ones
DELETE FROM public.forum_categories;
INSERT INTO public.forum_categories (name, slug, description, icon_name, display_order) VALUES
  ('Niagara', 'niagara', 'Discussions about Tridium Niagara Framework', 'Desktop', 1),
  ('Metasys', 'metasys', 'Johnson Controls Metasys discussions', 'Buildings', 2),
  ('General BAS', 'general-bas', 'General building automation topics', 'Wrench', 3),
  ('Off Topic', 'off-topic', 'Non-BAS discussions and community chat', 'Chats', 4),
  ('NiagaraSidekick', 'niagarasidekick', 'NiagaraSidekick tool support and discussion', 'Desktop', 5),
  ('SimulatorSidekick', 'simulatorsidekick', 'SimulatorSidekick tool support and discussion', 'WaveTriangle', 6),
  ('MetasysSidekick', 'metasyssidekick', 'MetasysSidekick tool support and discussion', 'Buildings', 7),
  ('Suggestions & Help', 'suggestions-help', 'Feature requests, bug reports, and getting help', 'Lifebuoy', 8);
-- ============================================================
-- PROFILE ENHANCEMENTS
-- ============================================================

-- Add post_count column (tracks total forum posts by user)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS post_count INT DEFAULT 0;
-- Add is_admin column (for moderation features)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT false;
-- Create index for leaderboard/top posters queries
CREATE INDEX IF NOT EXISTS idx_profiles_post_count
  ON public.profiles(post_count DESC);
-- Add display_name length constraint (3-30 characters)
-- Drop existing constraint if it exists, then create new one
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.table_constraints
             WHERE constraint_name = 'display_name_length' AND table_name = 'profiles') THEN
    ALTER TABLE public.profiles DROP CONSTRAINT display_name_length;
  END IF;
END $$;
ALTER TABLE public.profiles
  ADD CONSTRAINT display_name_length
  CHECK (
    display_name IS NULL OR
    (LENGTH(TRIM(display_name)) >= 3 AND LENGTH(TRIM(display_name)) <= 30)
  );
-- ============================================================
-- POST COUNT TRIGGERS
-- ============================================================

-- Function to increment post count when user creates a forum post
CREATE OR REPLACE FUNCTION public.increment_user_post_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.profiles
    SET post_count = COALESCE(post_count, 0) + 1
    WHERE id = NEW.author_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Function to decrement post count when user's forum post is deleted
CREATE OR REPLACE FUNCTION public.decrement_user_post_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    UPDATE public.profiles
    SET post_count = GREATEST(0, COALESCE(post_count, 0) - 1)
    WHERE id = OLD.author_id;
  END IF;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Create triggers on forum_posts
DROP TRIGGER IF EXISTS on_forum_post_created ON public.forum_posts;
CREATE TRIGGER on_forum_post_created
  AFTER INSERT ON public.forum_posts
  FOR EACH ROW
  EXECUTE FUNCTION public.increment_user_post_count();
DROP TRIGGER IF EXISTS on_forum_post_deleted ON public.forum_posts;
CREATE TRIGGER on_forum_post_deleted
  AFTER DELETE ON public.forum_posts
  FOR EACH ROW
  EXECUTE FUNCTION public.decrement_user_post_count();
-- Backfill existing post counts
UPDATE public.profiles p
SET post_count = (
  SELECT COUNT(*)
  FROM public.forum_posts fp
  WHERE fp.author_id = p.id
);
-- ============================================================
-- WIKI SUGGESTIONS TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.wiki_suggestions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_id UUID REFERENCES public.forum_threads(id) ON DELETE CASCADE NOT NULL,
  suggested_by UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  suggested_at TIMESTAMPTZ DEFAULT now(),
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  reviewed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ,
  notes TEXT,
  -- Prevent duplicate suggestions for the same thread by the same user
  CONSTRAINT unique_thread_suggestion UNIQUE (thread_id, suggested_by)
);
-- Enable RLS
ALTER TABLE public.wiki_suggestions ENABLE ROW LEVEL SECURITY;
-- RLS Policies for wiki_suggestions

-- Anyone can view suggestions (transparency)
DROP POLICY IF EXISTS "Wiki suggestions are viewable by everyone" ON public.wiki_suggestions;
CREATE POLICY "Wiki suggestions are viewable by everyone"
  ON public.wiki_suggestions FOR SELECT
  USING (true);
-- Authenticated users can create suggestions
DROP POLICY IF EXISTS "Authenticated users can create wiki suggestions" ON public.wiki_suggestions;
CREATE POLICY "Authenticated users can create wiki suggestions"
  ON public.wiki_suggestions FOR INSERT
  WITH CHECK (auth.uid() = suggested_by);
-- Only admins can update (approve/reject) suggestions
DROP POLICY IF EXISTS "Admins can update wiki suggestions" ON public.wiki_suggestions;
CREATE POLICY "Admins can update wiki suggestions"
  ON public.wiki_suggestions FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  );
-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_wiki_suggestions_status
  ON public.wiki_suggestions(status);
CREATE INDEX IF NOT EXISTS idx_wiki_suggestions_thread
  ON public.wiki_suggestions(thread_id);
CREATE INDEX IF NOT EXISTS idx_wiki_suggestions_suggested_by
  ON public.wiki_suggestions(suggested_by);
