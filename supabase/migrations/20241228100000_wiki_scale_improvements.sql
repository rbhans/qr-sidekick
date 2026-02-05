-- Wiki Scale Improvements Migration
-- Run this when you're ready to optimize for larger article counts

-- ===========================================
-- 1. INDEXES FOR COMMON QUERY PATTERNS
-- ===========================================

-- Articles: filter by category + published + order by date
CREATE INDEX IF NOT EXISTS idx_wiki_articles_category_published
  ON wiki_articles(category_id, is_published, created_at DESC);
-- Articles: filter by author (for "my articles" view)
CREATE INDEX IF NOT EXISTS idx_wiki_articles_author
  ON wiki_articles(author_id) WHERE author_id IS NOT NULL;
-- Articles: popular articles (for homepage/recommendations)
CREATE INDEX IF NOT EXISTS idx_wiki_articles_popular
  ON wiki_articles(view_count DESC) WHERE is_published = true;
-- Comments: by article (most common access pattern)
CREATE INDEX IF NOT EXISTS idx_wiki_comments_article
  ON wiki_comments(article_id, created_at);
-- Article tags: both directions for junction table
CREATE INDEX IF NOT EXISTS idx_wiki_article_tags_tag
  ON wiki_article_tags(tag_id);
-- Categories: parent lookup for tree building
CREATE INDEX IF NOT EXISTS idx_wiki_categories_parent
  ON wiki_categories(parent_id) WHERE parent_id IS NOT NULL;
-- ===========================================
-- 2. FULL-TEXT SEARCH SUPPORT
-- ===========================================

-- Add tsvector column for full-text search
ALTER TABLE wiki_articles
  ADD COLUMN IF NOT EXISTS search_vector tsvector;
-- Create GIN index for fast full-text search
CREATE INDEX IF NOT EXISTS idx_wiki_articles_search
  ON wiki_articles USING GIN(search_vector);
-- Function to update search vector
CREATE OR REPLACE FUNCTION wiki_articles_search_trigger()
RETURNS trigger AS $$
BEGIN
  NEW.search_vector :=
    setweight(to_tsvector('english', coalesce(NEW.title, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(NEW.summary, '')), 'B') ||
    setweight(to_tsvector('english', coalesce(NEW.content, '')), 'C');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
-- Trigger to auto-update search vector
DROP TRIGGER IF EXISTS wiki_articles_search_update ON wiki_articles;
CREATE TRIGGER wiki_articles_search_update
  BEFORE INSERT OR UPDATE OF title, summary, content
  ON wiki_articles
  FOR EACH ROW
  EXECUTE FUNCTION wiki_articles_search_trigger();
-- Backfill existing articles (run once)
UPDATE wiki_articles SET search_vector =
  setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
  setweight(to_tsvector('english', coalesce(summary, '')), 'B') ||
  setweight(to_tsvector('english', coalesce(content, '')), 'C');
-- ===========================================
-- 3. ARTICLE REVISION HISTORY
-- ===========================================

CREATE TABLE IF NOT EXISTS wiki_article_revisions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  article_id UUID REFERENCES wiki_articles(id) ON DELETE CASCADE NOT NULL,
  editor_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  summary TEXT,
  content TEXT NOT NULL,
  revision_number INT NOT NULL,
  change_summary TEXT, -- "Updated introduction", "Fixed typo", etc.
  created_at TIMESTAMPTZ DEFAULT now()
);
-- Index for fetching article history
CREATE INDEX IF NOT EXISTS idx_wiki_revisions_article
  ON wiki_article_revisions(article_id, revision_number DESC);
-- Enable RLS
ALTER TABLE wiki_article_revisions ENABLE ROW LEVEL SECURITY;
-- Anyone can view revision history of published articles
CREATE POLICY "Anyone can view revisions of published articles"
  ON wiki_article_revisions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM wiki_articles
      WHERE wiki_articles.id = wiki_article_revisions.article_id
      AND wiki_articles.is_published = true
    )
  );
-- ===========================================
-- 4. THREADED COMMENTS (OPTIONAL)
-- ===========================================

-- Add parent_id for nested comment threads
ALTER TABLE wiki_comments
  ADD COLUMN IF NOT EXISTS parent_id UUID REFERENCES wiki_comments(id) ON DELETE CASCADE;
-- Index for loading comment trees
CREATE INDEX IF NOT EXISTS idx_wiki_comments_parent
  ON wiki_comments(parent_id) WHERE parent_id IS NOT NULL;
-- ===========================================
-- 5. TAG USAGE COUNTS (DENORMALIZED)
-- ===========================================

-- Add article count to tags for "popular tags" without joins
ALTER TABLE wiki_tags
  ADD COLUMN IF NOT EXISTS article_count INT DEFAULT 0;
-- Function to update tag counts
CREATE OR REPLACE FUNCTION update_tag_article_count()
RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE wiki_tags SET article_count = article_count + 1 WHERE id = NEW.tag_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE wiki_tags SET article_count = article_count - 1 WHERE id = OLD.tag_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;
-- Trigger on junction table
DROP TRIGGER IF EXISTS wiki_article_tags_count ON wiki_article_tags;
CREATE TRIGGER wiki_article_tags_count
  AFTER INSERT OR DELETE ON wiki_article_tags
  FOR EACH ROW
  EXECUTE FUNCTION update_tag_article_count();
-- ===========================================
-- 6. CATEGORY ARTICLE COUNTS (DENORMALIZED)
-- ===========================================

-- Add article count to categories
ALTER TABLE wiki_categories
  ADD COLUMN IF NOT EXISTS article_count INT DEFAULT 0;
-- Function to update category counts
CREATE OR REPLACE FUNCTION update_category_article_count()
RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.category_id IS NOT NULL AND NEW.is_published = true THEN
      UPDATE wiki_categories SET article_count = article_count + 1 WHERE id = NEW.category_id;
    END IF;
  ELSIF TG_OP = 'DELETE' THEN
    IF OLD.category_id IS NOT NULL AND OLD.is_published = true THEN
      UPDATE wiki_categories SET article_count = article_count - 1 WHERE id = OLD.category_id;
    END IF;
  ELSIF TG_OP = 'UPDATE' THEN
    -- Handle category change or publish/unpublish
    IF OLD.category_id IS DISTINCT FROM NEW.category_id OR OLD.is_published IS DISTINCT FROM NEW.is_published THEN
      IF OLD.category_id IS NOT NULL AND OLD.is_published = true THEN
        UPDATE wiki_categories SET article_count = article_count - 1 WHERE id = OLD.category_id;
      END IF;
      IF NEW.category_id IS NOT NULL AND NEW.is_published = true THEN
        UPDATE wiki_categories SET article_count = article_count + 1 WHERE id = NEW.category_id;
      END IF;
    END IF;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;
-- Trigger on articles
DROP TRIGGER IF EXISTS wiki_articles_category_count ON wiki_articles;
CREATE TRIGGER wiki_articles_category_count
  AFTER INSERT OR UPDATE OR DELETE ON wiki_articles
  FOR EACH ROW
  EXECUTE FUNCTION update_category_article_count();
