-- ============================================================
-- POINTSTACK PROJECT UNIFICATION (POSTS-BASED SHOWCASE)
-- ============================================================

ALTER TABLE public.pointstack_posts
  ADD COLUMN IF NOT EXISTS is_showcase BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS cover_image_url TEXT,
  ADD COLUMN IF NOT EXISTS images TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS documents TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS building_types TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS systems TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS technologies TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS location TEXT,
  ADD COLUMN IF NOT EXISTS completion_date DATE,
  ADD COLUMN IF NOT EXISTS square_footage INT,
  ADD COLUMN IF NOT EXISTS company_id UUID REFERENCES public.pointstack_companies(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS is_featured BOOLEAN DEFAULT false;
CREATE INDEX IF NOT EXISTS idx_pointstack_posts_showcase
  ON public.pointstack_posts (is_showcase)
  WHERE is_showcase = true;
CREATE INDEX IF NOT EXISTS idx_pointstack_posts_building_types
  ON public.pointstack_posts USING GIN (building_types);
CREATE INDEX IF NOT EXISTS idx_pointstack_posts_systems
  ON public.pointstack_posts USING GIN (systems);
CREATE INDEX IF NOT EXISTS idx_pointstack_posts_technologies
  ON public.pointstack_posts USING GIN (technologies);
CREATE INDEX IF NOT EXISTS idx_pointstack_posts_company
  ON public.pointstack_posts (company_id);
-- ============================================================
-- STORAGE BUCKET FOR PROJECT ATTACHMENTS
-- ============================================================

INSERT INTO storage.buckets (id, name, public)
VALUES ('pointstack-posts', 'pointstack-posts', true)
ON CONFLICT (id) DO NOTHING;
CREATE POLICY "Anyone can view pointstack post files"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'pointstack-posts');
CREATE POLICY "Authenticated users can upload pointstack post files"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'pointstack-posts' AND auth.role() = 'authenticated');
CREATE POLICY "Users can update their own pointstack post files"
  ON storage.objects FOR UPDATE
  USING (bucket_id = 'pointstack-posts' AND auth.uid()::text = (storage.foldername(name))[1]);
CREATE POLICY "Users can delete their own pointstack post files"
  ON storage.objects FOR DELETE
  USING (bucket_id = 'pointstack-posts' AND auth.uid()::text = (storage.foldername(name))[1]);
