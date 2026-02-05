-- ============================================================
-- BABEL CONTRIBUTIONS
-- User-submitted contributions for BAS Babel entries
-- Allows non-technical users to suggest edits, report errors,
-- and request new entries without needing GitHub knowledge
-- ============================================================

-- Create the babel_contributions table
CREATE TABLE public.babel_contributions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Contribution type
  type TEXT NOT NULL CHECK (type IN ('error', 'edit', 'new_entry')),

  -- Entry reference (null for new_entry requests)
  entry_id TEXT,           -- e.g., "zone_temp_sp" or "ahu"
  entry_type TEXT,         -- 'point' or 'equipment'
  entry_category TEXT,     -- e.g., "setpoints" or "air-handling"

  -- Content
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  suggested_changes JSONB, -- For edits: { field: value } pairs

  -- Status tracking
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  reviewer_notes TEXT,
  reviewed_by UUID REFERENCES auth.users(id),
  reviewed_at TIMESTAMPTZ,

  -- GitHub integration
  github_issue_url TEXT,

  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
-- Create indexes for common queries
CREATE INDEX idx_babel_contributions_user_id ON public.babel_contributions(user_id);
CREATE INDEX idx_babel_contributions_status ON public.babel_contributions(status);
CREATE INDEX idx_babel_contributions_created_at ON public.babel_contributions(created_at DESC);
CREATE INDEX idx_babel_contributions_type ON public.babel_contributions(type);
-- Enable Row Level Security
ALTER TABLE public.babel_contributions ENABLE ROW LEVEL SECURITY;
-- ============================================================
-- RLS POLICIES
-- ============================================================

-- Users can read their own submissions
DROP POLICY IF EXISTS "Users can read own contributions" ON public.babel_contributions;
CREATE POLICY "Users can read own contributions"
  ON public.babel_contributions FOR SELECT
  USING (auth.uid() = user_id);
-- Users can insert their own submissions
DROP POLICY IF EXISTS "Users can create contributions" ON public.babel_contributions;
CREATE POLICY "Users can create contributions"
  ON public.babel_contributions FOR INSERT
  WITH CHECK (auth.uid() = user_id);
-- Admins can read all contributions
DROP POLICY IF EXISTS "Admins can read all contributions" ON public.babel_contributions;
CREATE POLICY "Admins can read all contributions"
  ON public.babel_contributions FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_admin = true)
  );
-- Admins can update contributions (for approval/rejection)
DROP POLICY IF EXISTS "Admins can update contributions" ON public.babel_contributions;
CREATE POLICY "Admins can update contributions"
  ON public.babel_contributions FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_admin = true)
  );
-- ============================================================
-- TRIGGER: Update updated_at on changes
-- ============================================================

CREATE OR REPLACE FUNCTION public.update_babel_contribution_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
DROP TRIGGER IF EXISTS trigger_babel_contributions_updated_at ON public.babel_contributions;
CREATE TRIGGER trigger_babel_contributions_updated_at
  BEFORE UPDATE ON public.babel_contributions
  FOR EACH ROW
  EXECUTE FUNCTION public.update_babel_contribution_updated_at();
