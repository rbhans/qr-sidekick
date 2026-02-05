-- ============================================================
-- BAS ATLAS EQUIPMENT DATA + COMMUNITY TABLES
-- ============================================================

-- ============================================================
-- EQUIPMENT SUBMISSIONS (moderated)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.equipment_submissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Contribution type
  type TEXT NOT NULL CHECK (type IN ('error', 'edit', 'new_entry')),

  -- Optional reference to existing model
  entry_id TEXT,

  -- Proposed/related brand & type
  brand_id TEXT,
  brand_name TEXT,
  brand_logo_url TEXT,
  type_id TEXT,
  type_name TEXT,

  -- Model details
  model_name TEXT,
  model_numbers TEXT[],
  protocols TEXT[],
  model_status TEXT CHECK (model_status IN ('current', 'discontinued')),
  description TEXT,
  manufacturer_url TEXT,
  image_url TEXT,

  -- For edit suggestions
  suggested_changes JSONB,

  -- Review status
  review_status TEXT DEFAULT 'pending' CHECK (review_status IN ('pending', 'approved', 'rejected')),
  reviewer_notes TEXT,
  reviewed_by UUID REFERENCES auth.users(id),
  reviewed_at TIMESTAMPTZ,

  -- GitHub integration
  github_issue_url TEXT,

  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_equipment_submissions_user_id ON public.equipment_submissions(user_id);
CREATE INDEX IF NOT EXISTS idx_equipment_submissions_status ON public.equipment_submissions(review_status);
CREATE INDEX IF NOT EXISTS idx_equipment_submissions_created_at ON public.equipment_submissions(created_at DESC);
ALTER TABLE public.equipment_submissions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own equipment submissions"
  ON public.equipment_submissions FOR SELECT
  USING (auth.uid() = user_id);
CREATE POLICY "Users can create equipment submissions"
  ON public.equipment_submissions FOR INSERT
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Admins can read equipment submissions"
  ON public.equipment_submissions FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_admin = true)
  );
CREATE POLICY "Admins can update equipment submissions"
  ON public.equipment_submissions FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_admin = true)
  );
-- Update updated_at
CREATE OR REPLACE FUNCTION public.update_equipment_submissions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
DROP TRIGGER IF EXISTS trigger_equipment_submissions_updated_at ON public.equipment_submissions;
CREATE TRIGGER trigger_equipment_submissions_updated_at
  BEFORE UPDATE ON public.equipment_submissions
  FOR EACH ROW
  EXECUTE FUNCTION public.update_equipment_submissions_updated_at();
-- ============================================================
-- EQUIPMENT NOTES + VOTES
-- ============================================================
CREATE TABLE IF NOT EXISTS public.equipment_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id TEXT NOT NULL,
  author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  upvote_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_equipment_notes_equipment_id ON public.equipment_notes(equipment_id);
CREATE INDEX IF NOT EXISTS idx_equipment_notes_created_at ON public.equipment_notes(created_at DESC);
ALTER TABLE public.equipment_notes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Equipment notes are viewable by everyone"
  ON public.equipment_notes FOR SELECT
  USING (true);
CREATE POLICY "Authenticated users can create equipment notes"
  ON public.equipment_notes FOR INSERT
  WITH CHECK (auth.uid() = author_id);
CREATE POLICY "Users can update their equipment notes"
  ON public.equipment_notes FOR UPDATE
  USING (auth.uid() = author_id);
CREATE POLICY "Users can delete their equipment notes"
  ON public.equipment_notes FOR DELETE
  USING (auth.uid() = author_id);
CREATE OR REPLACE FUNCTION public.update_equipment_notes_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
DROP TRIGGER IF EXISTS trigger_equipment_notes_updated_at ON public.equipment_notes;
CREATE TRIGGER trigger_equipment_notes_updated_at
  BEFORE UPDATE ON public.equipment_notes
  FOR EACH ROW
  EXECUTE FUNCTION public.update_equipment_notes_updated_at();
CREATE TABLE IF NOT EXISTS public.equipment_note_votes (
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  note_id UUID NOT NULL REFERENCES public.equipment_notes(id) ON DELETE CASCADE,
  vote_type INT NOT NULL CHECK (vote_type IN (1)),
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (user_id, note_id)
);
ALTER TABLE public.equipment_note_votes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Equipment note votes are viewable by everyone"
  ON public.equipment_note_votes FOR SELECT
  USING (true);
CREATE POLICY "Authenticated users can vote on equipment notes"
  ON public.equipment_note_votes FOR INSERT
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can remove their equipment note votes"
  ON public.equipment_note_votes FOR DELETE
  USING (auth.uid() = user_id);
-- Maintain upvote counts
CREATE OR REPLACE FUNCTION public.update_equipment_note_upvotes()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.equipment_notes
    SET upvote_count = upvote_count + 1
    WHERE id = NEW.note_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.equipment_notes
    SET upvote_count = GREATEST(0, upvote_count - 1)
    WHERE id = OLD.note_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
DROP TRIGGER IF EXISTS trigger_equipment_note_upvotes ON public.equipment_note_votes;
CREATE TRIGGER trigger_equipment_note_upvotes
  AFTER INSERT OR DELETE ON public.equipment_note_votes
  FOR EACH ROW
  EXECUTE FUNCTION public.update_equipment_note_upvotes();
-- ============================================================
-- EQUIPMENT EXPERIENCE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.equipment_experience (
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  equipment_id TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (user_id, equipment_id)
);
CREATE INDEX IF NOT EXISTS idx_equipment_experience_equipment_id ON public.equipment_experience(equipment_id);
ALTER TABLE public.equipment_experience ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Equipment experience is viewable by everyone"
  ON public.equipment_experience FOR SELECT
  USING (true);
CREATE POLICY "Users can add equipment experience"
  ON public.equipment_experience FOR INSERT
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can remove equipment experience"
  ON public.equipment_experience FOR DELETE
  USING (auth.uid() = user_id);
-- ============================================================
-- EQUIPMENT IMAGES
-- ============================================================
CREATE TABLE IF NOT EXISTS public.equipment_images (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id TEXT NOT NULL,
  uploaded_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  url TEXT NOT NULL,
  storage_path TEXT,
  is_primary BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_equipment_images_equipment_id ON public.equipment_images(equipment_id);
ALTER TABLE public.equipment_images ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Equipment images are viewable by everyone"
  ON public.equipment_images FOR SELECT
  USING (true);
CREATE POLICY "Authenticated users can upload equipment images"
  ON public.equipment_images FOR INSERT
  WITH CHECK (auth.uid() = uploaded_by);
CREATE POLICY "Users can delete their equipment images"
  ON public.equipment_images FOR DELETE
  USING (auth.uid() = uploaded_by);
-- ============================================================
-- POINTSTACK POSTS: EQUIPMENT TAGS
-- ============================================================
ALTER TABLE public.pointstack_posts
  ADD COLUMN IF NOT EXISTS equipment_ids TEXT[] DEFAULT '{}';
CREATE INDEX IF NOT EXISTS idx_pointstack_posts_equipment_ids
  ON public.pointstack_posts USING GIN (equipment_ids);
-- Showcase projects equipment tags (optional)
ALTER TABLE public.pointstack_showcase_projects
  ADD COLUMN IF NOT EXISTS equipment_ids TEXT[] DEFAULT '{}';
CREATE INDEX IF NOT EXISTS idx_pointstack_showcase_equipment_ids
  ON public.pointstack_showcase_projects USING GIN (equipment_ids);
-- ============================================================
-- STORAGE BUCKETS (equipment images)
-- ============================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('equipment-images', 'equipment-images', true)
ON CONFLICT (id) DO NOTHING;
CREATE POLICY "Anyone can view equipment images"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'equipment-images');
CREATE POLICY "Authenticated users can upload equipment images"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'equipment-images' AND auth.role() = 'authenticated');
CREATE POLICY "Users can update their own equipment images"
  ON storage.objects FOR UPDATE
  USING (bucket_id = 'equipment-images' AND auth.uid()::text = (storage.foldername(name))[1]);
CREATE POLICY "Users can delete their own equipment images"
  ON storage.objects FOR DELETE
  USING (bucket_id = 'equipment-images' AND auth.uid()::text = (storage.foldername(name))[1]);
