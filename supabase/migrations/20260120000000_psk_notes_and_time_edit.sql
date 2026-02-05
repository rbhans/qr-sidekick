-- ============================================================
-- PSK Notes & Time Entry Update
-- Adds project notes/log and enables time entry editing
-- ============================================================

-- ============================================================
-- PSK NOTES TABLE (Site Log / Work Notes)
-- ============================================================

CREATE TABLE public.psk_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  project_id UUID NOT NULL REFERENCES public.psk_projects(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);
-- Enable RLS
ALTER TABLE public.psk_notes ENABLE ROW LEVEL SECURITY;
-- Create indexes
CREATE INDEX idx_psk_notes_user_id ON public.psk_notes(user_id);
CREATE INDEX idx_psk_notes_project_id ON public.psk_notes(project_id);
CREATE INDEX idx_psk_notes_created_by ON public.psk_notes(created_by);
CREATE INDEX idx_psk_notes_created_at ON public.psk_notes(created_at DESC);
-- RLS Policies for psk_notes
-- Users can view notes on their own projects
CREATE POLICY "Users can view notes on own projects"
  ON public.psk_notes FOR SELECT
  USING (
    user_id = auth.uid()
    OR project_id IN (
      SELECT id FROM psk_projects
      WHERE user_id = auth.uid()
    )
  );
-- Users can view notes on company projects they're a member of
CREATE POLICY "Company members can view notes on company projects"
  ON public.psk_notes FOR SELECT
  USING (
    project_id IN (
      SELECT p.id FROM psk_projects p
      WHERE p.company_id IN (
        SELECT company_id FROM psk_company_members WHERE user_id = auth.uid()
      )
    )
  );
-- Authenticated users can create notes on projects they have access to
CREATE POLICY "Users can create notes on accessible projects"
  ON public.psk_notes FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND (
      -- Own project
      project_id IN (
        SELECT id FROM psk_projects WHERE user_id = auth.uid()
      )
      OR
      -- Company project user is member of
      project_id IN (
        SELECT p.id FROM psk_projects p
        WHERE p.company_id IN (
          SELECT company_id FROM psk_company_members WHERE user_id = auth.uid()
        )
      )
    )
  );
-- Users can update their own notes
CREATE POLICY "Users can update own notes"
  ON public.psk_notes FOR UPDATE
  USING (created_by = auth.uid());
-- Users can delete their own notes
CREATE POLICY "Users can delete own notes"
  ON public.psk_notes FOR DELETE
  USING (created_by = auth.uid());
-- ============================================================
-- TIME ENTRY UPDATE POLICY
-- Enable updating time entries (was missing before)
-- ============================================================

-- Users can update their own time entries
CREATE POLICY "Users can update own time entries"
  ON public.psk_time_entries FOR UPDATE
  USING (created_by = auth.uid() OR user_id = auth.uid());
