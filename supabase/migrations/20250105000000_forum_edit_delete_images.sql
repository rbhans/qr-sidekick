-- Migration: Forum Edit/Delete Posts & Image Upload Support
-- Date: 2025-01-05
-- Description: Adds is_edited column to forum_posts, DELETE RLS policy,
--              and storage bucket for forum images

-- ============================================
-- FORUM_POSTS ENHANCEMENTS
-- ============================================

-- Add is_edited column to track when posts have been modified
ALTER TABLE public.forum_posts
  ADD COLUMN IF NOT EXISTS is_edited BOOLEAN DEFAULT false;
-- Add DELETE RLS policy for authors to delete their own posts
CREATE POLICY "Authors can delete their posts"
  ON public.forum_posts FOR DELETE
  USING (auth.uid() = author_id);
-- Index for efficient author lookups on delete/edit operations
CREATE INDEX IF NOT EXISTS idx_forum_posts_author_id
  ON public.forum_posts(author_id);
-- ============================================
-- FORUM_THREADS DELETE POLICY
-- ============================================

-- Add DELETE RLS policy for thread authors (for when first post is deleted)
CREATE POLICY "Authors can delete their threads"
  ON public.forum_threads FOR DELETE
  USING (auth.uid() = author_id);
-- ============================================
-- STORAGE BUCKET: forum-assets
-- ============================================

-- Create the storage bucket for forum images
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'forum-assets',
  'forum-assets',
  true,
  5242880, -- 5MB
  ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
-- Storage policy: Users can upload to their own folder
CREATE POLICY "Users can upload forum images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'forum-assets'
  AND (storage.foldername(name))[1] = auth.uid()::text
);
-- Storage policy: Public read access for all forum images
CREATE POLICY "Public read access for forum images"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'forum-assets');
-- Storage policy: Users can update their own images
CREATE POLICY "Users can update own forum images"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'forum-assets'
  AND (storage.foldername(name))[1] = auth.uid()::text
);
-- Storage policy: Users can delete their own images
CREATE POLICY "Users can delete own forum images"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'forum-assets'
  AND (storage.foldername(name))[1] = auth.uid()::text
);
