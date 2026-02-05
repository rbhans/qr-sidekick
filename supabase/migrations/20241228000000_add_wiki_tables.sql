-- Wiki Categories (supports nesting via parent_id)
CREATE TABLE wiki_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_id UUID REFERENCES wiki_categories(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  description TEXT,
  icon_name TEXT,
  display_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);
-- Wiki Tags
CREATE TABLE wiki_tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  slug TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT now()
);
-- Wiki Articles
CREATE TABLE wiki_articles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id UUID REFERENCES wiki_categories(id) ON DELETE SET NULL,
  author_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  summary TEXT,
  content TEXT NOT NULL,
  is_published BOOLEAN DEFAULT false,
  view_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
-- Wiki Article Tags (many-to-many)
CREATE TABLE wiki_article_tags (
  article_id UUID REFERENCES wiki_articles(id) ON DELETE CASCADE,
  tag_id UUID REFERENCES wiki_tags(id) ON DELETE CASCADE,
  PRIMARY KEY (article_id, tag_id)
);
-- Wiki Comments
CREATE TABLE wiki_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  article_id UUID REFERENCES wiki_articles(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  content TEXT NOT NULL,
  is_edited BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
-- Enable RLS
ALTER TABLE wiki_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE wiki_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE wiki_articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE wiki_article_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE wiki_comments ENABLE ROW LEVEL SECURITY;
-- RLS Policies for wiki_categories (public read)
CREATE POLICY "Anyone can view wiki categories"
  ON wiki_categories FOR SELECT
  USING (true);
-- RLS Policies for wiki_tags (public read)
CREATE POLICY "Anyone can view wiki tags"
  ON wiki_tags FOR SELECT
  USING (true);
-- RLS Policies for wiki_articles
CREATE POLICY "Anyone can view published articles"
  ON wiki_articles FOR SELECT
  USING (is_published = true);
CREATE POLICY "Authors can view own unpublished articles"
  ON wiki_articles FOR SELECT
  USING (author_id = auth.uid());
CREATE POLICY "Authors can insert articles"
  ON wiki_articles FOR INSERT
  WITH CHECK (auth.uid() = author_id);
CREATE POLICY "Authors can update own articles"
  ON wiki_articles FOR UPDATE
  USING (auth.uid() = author_id);
-- RLS Policies for wiki_article_tags
CREATE POLICY "Anyone can view article tags"
  ON wiki_article_tags FOR SELECT
  USING (true);
-- RLS Policies for wiki_comments
CREATE POLICY "Anyone can view comments"
  ON wiki_comments FOR SELECT
  USING (true);
CREATE POLICY "Authenticated users can insert comments"
  ON wiki_comments FOR INSERT
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own comments"
  ON wiki_comments FOR UPDATE
  USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own comments"
  ON wiki_comments FOR DELETE
  USING (auth.uid() = user_id);
-- Trigger to update updated_at on articles
CREATE TRIGGER update_wiki_articles_updated_at
  BEFORE UPDATE ON wiki_articles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
-- Trigger to update updated_at on comments
CREATE TRIGGER update_wiki_comments_updated_at
  BEFORE UPDATE ON wiki_comments
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
-- Seed initial categories based on your structure
INSERT INTO wiki_categories (name, slug, description, icon_name, display_order) VALUES
  ('Issues & Solutions', 'issues-solutions', 'Troubleshooting guides and fixes for common problems', 'Warning', 1),
  ('How-To Guides', 'how-to-guides', 'Step-by-step tutorials and procedures', 'Book', 2),
  ('Best Practices', 'best-practices', 'Industry standards and recommended approaches', 'CheckCircle', 3),
  ('BASidekick Documentation', 'basidekick-docs', 'Official documentation for BASidekick tools', 'Desktop', 4);
-- Add subcategories
INSERT INTO wiki_categories (parent_id, name, slug, description, icon_name, display_order)
SELECT id, 'Niagara', 'issues-solutions-niagara', 'Niagara-specific troubleshooting', 'Desktop', 1
FROM wiki_categories WHERE slug = 'issues-solutions';
INSERT INTO wiki_categories (parent_id, name, slug, description, icon_name, display_order)
SELECT id, 'Metasys', 'issues-solutions-metasys', 'Metasys/JCI troubleshooting', 'Buildings', 2
FROM wiki_categories WHERE slug = 'issues-solutions';
INSERT INTO wiki_categories (parent_id, name, slug, description, icon_name, display_order)
SELECT id, 'General BAS', 'issues-solutions-general', 'General building automation topics', 'Wrench', 3
FROM wiki_categories WHERE slug = 'issues-solutions';
INSERT INTO wiki_categories (parent_id, name, slug, description, icon_name, display_order)
SELECT id, 'Niagara', 'how-to-niagara', 'Niagara how-to guides', 'Desktop', 1
FROM wiki_categories WHERE slug = 'how-to-guides';
INSERT INTO wiki_categories (parent_id, name, slug, description, icon_name, display_order)
SELECT id, 'Metasys', 'how-to-metasys', 'Metasys how-to guides', 'Buildings', 2
FROM wiki_categories WHERE slug = 'how-to-guides';
INSERT INTO wiki_categories (parent_id, name, slug, description, icon_name, display_order)
SELECT id, 'General BAS', 'how-to-general', 'General BAS how-to guides', 'Wrench', 3
FROM wiki_categories WHERE slug = 'how-to-guides';
INSERT INTO wiki_categories (parent_id, name, slug, description, icon_name, display_order)
SELECT id, 'Niagara', 'best-practices-niagara', 'Niagara best practices', 'Desktop', 1
FROM wiki_categories WHERE slug = 'best-practices';
INSERT INTO wiki_categories (parent_id, name, slug, description, icon_name, display_order)
SELECT id, 'Metasys', 'best-practices-metasys', 'Metasys best practices', 'Buildings', 2
FROM wiki_categories WHERE slug = 'best-practices';
INSERT INTO wiki_categories (parent_id, name, slug, description, icon_name, display_order)
SELECT id, 'General BAS', 'best-practices-general', 'General BAS best practices', 'Wrench', 3
FROM wiki_categories WHERE slug = 'best-practices';
INSERT INTO wiki_categories (parent_id, name, slug, description, icon_name, display_order)
SELECT id, 'NiagaraSidekick', 'docs-niagarasidekick', 'NiagaraSidekick documentation', 'Desktop', 1
FROM wiki_categories WHERE slug = 'basidekick-docs';
INSERT INTO wiki_categories (parent_id, name, slug, description, icon_name, display_order)
SELECT id, 'SimulatorSidekick', 'docs-simulatorsidekick', 'SimulatorSidekick documentation', 'WaveTriangle', 2
FROM wiki_categories WHERE slug = 'basidekick-docs';
INSERT INTO wiki_categories (parent_id, name, slug, description, icon_name, display_order)
SELECT id, 'MetasysSidekick', 'docs-metasyssidekick', 'MetasysSidekick documentation', 'Buildings', 3
FROM wiki_categories WHERE slug = 'basidekick-docs';
INSERT INTO wiki_categories (parent_id, name, slug, description, icon_name, display_order)
SELECT id, 'ProjectSidekick', 'docs-projectsidekick', 'ProjectSidekick documentation', 'Kanban', 4
FROM wiki_categories WHERE slug = 'basidekick-docs';
-- Seed common tags
INSERT INTO wiki_tags (name, slug) VALUES
  ('niagara', 'niagara'),
  ('metasys', 'metasys'),
  ('bacnet', 'bacnet'),
  ('troubleshooting', 'troubleshooting'),
  ('graphics', 'graphics'),
  ('networking', 'networking'),
  ('security', 'security'),
  ('performance', 'performance'),
  ('commissioning', 'commissioning'),
  ('best-practices', 'best-practices'),
  ('px', 'px'),
  ('mstp', 'mstp'),
  ('certificate', 'certificate'),
  ('authentication', 'authentication'),
  ('database', 'database');
