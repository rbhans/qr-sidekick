-- PSK Collaboration Migration
-- Adds company/team collaboration features to Project SideKick
-- Users can create companies, invite others via link, and share projects/clients

-- ============================================================
-- NEW TABLES
-- ============================================================

-- Companies table
CREATE TABLE IF NOT EXISTS psk_companies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  invite_code UUID UNIQUE DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
-- Company members junction table
CREATE TABLE IF NOT EXISTS psk_company_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES psk_companies(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT DEFAULT 'member' CHECK (role IN ('owner', 'member')),
  joined_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(company_id, user_id)
);
-- ============================================================
-- ALTER EXISTING TABLES - Add company_id and created_by columns
-- ============================================================

-- Add company_id to psk_clients
ALTER TABLE psk_clients
ADD COLUMN IF NOT EXISTS company_id UUID REFERENCES psk_companies(id) ON DELETE CASCADE;
-- Add company_id and created_by to psk_projects
ALTER TABLE psk_projects
ADD COLUMN IF NOT EXISTS company_id UUID REFERENCES psk_companies(id) ON DELETE CASCADE;
ALTER TABLE psk_projects
ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id);
-- Add created_by to psk_tasks
ALTER TABLE psk_tasks
ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id);
-- Add created_by to psk_time_entries
ALTER TABLE psk_time_entries
ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id);
-- Add created_by to psk_budget_line_items
ALTER TABLE psk_budget_line_items
ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id);
-- Add created_by to psk_files
ALTER TABLE psk_files
ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id);
-- ============================================================
-- INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_psk_companies_owner_id ON psk_companies(owner_id);
CREATE INDEX IF NOT EXISTS idx_psk_companies_slug ON psk_companies(slug);
CREATE INDEX IF NOT EXISTS idx_psk_companies_invite_code ON psk_companies(invite_code);
CREATE INDEX IF NOT EXISTS idx_psk_company_members_company_id ON psk_company_members(company_id);
CREATE INDEX IF NOT EXISTS idx_psk_company_members_user_id ON psk_company_members(user_id);
CREATE INDEX IF NOT EXISTS idx_psk_clients_company_id ON psk_clients(company_id);
CREATE INDEX IF NOT EXISTS idx_psk_projects_company_id ON psk_projects(company_id);
CREATE INDEX IF NOT EXISTS idx_psk_projects_created_by ON psk_projects(created_by);
CREATE INDEX IF NOT EXISTS idx_psk_tasks_created_by ON psk_tasks(created_by);
-- ============================================================
-- ROW LEVEL SECURITY - Enable on new tables
-- ============================================================

ALTER TABLE psk_companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE psk_company_members ENABLE ROW LEVEL SECURITY;
-- ============================================================
-- DROP EXISTING POLICIES (to replace with collaborative ones)
-- ============================================================

-- psk_clients policies
DROP POLICY IF EXISTS "Users can view their own clients" ON psk_clients;
DROP POLICY IF EXISTS "Users can create their own clients" ON psk_clients;
DROP POLICY IF EXISTS "Users can update their own clients" ON psk_clients;
DROP POLICY IF EXISTS "Users can delete their own clients" ON psk_clients;
-- psk_projects policies
DROP POLICY IF EXISTS "Users can view their own projects" ON psk_projects;
DROP POLICY IF EXISTS "Users can create their own projects" ON psk_projects;
DROP POLICY IF EXISTS "Users can update their own projects" ON psk_projects;
DROP POLICY IF EXISTS "Users can delete their own projects" ON psk_projects;
-- psk_tasks policies
DROP POLICY IF EXISTS "Users can view their own tasks" ON psk_tasks;
DROP POLICY IF EXISTS "Users can create their own tasks" ON psk_tasks;
DROP POLICY IF EXISTS "Users can update their own tasks" ON psk_tasks;
DROP POLICY IF EXISTS "Users can delete their own tasks" ON psk_tasks;
-- psk_time_entries policies
DROP POLICY IF EXISTS "Users can view their own time entries" ON psk_time_entries;
DROP POLICY IF EXISTS "Users can create their own time entries" ON psk_time_entries;
DROP POLICY IF EXISTS "Users can update their own time entries" ON psk_time_entries;
DROP POLICY IF EXISTS "Users can delete their own time entries" ON psk_time_entries;
-- psk_budget_line_items policies
DROP POLICY IF EXISTS "Users can view their own budget items" ON psk_budget_line_items;
DROP POLICY IF EXISTS "Users can create their own budget items" ON psk_budget_line_items;
DROP POLICY IF EXISTS "Users can update their own budget items" ON psk_budget_line_items;
DROP POLICY IF EXISTS "Users can delete their own budget items" ON psk_budget_line_items;
-- psk_files policies
DROP POLICY IF EXISTS "Users can view their own files" ON psk_files;
DROP POLICY IF EXISTS "Users can create their own files" ON psk_files;
DROP POLICY IF EXISTS "Users can update their own files" ON psk_files;
DROP POLICY IF EXISTS "Users can delete their own files" ON psk_files;
-- ============================================================
-- NEW RLS POLICIES - Companies
-- ============================================================

-- View companies user is a member of
CREATE POLICY "Users can view companies they belong to"
  ON psk_companies FOR SELECT
  USING (
    id IN (SELECT company_id FROM psk_company_members WHERE user_id = auth.uid())
  );
-- Create companies (user becomes owner)
CREATE POLICY "Authenticated users can create companies"
  ON psk_companies FOR INSERT
  WITH CHECK (auth.uid() = owner_id);
-- Update companies (owner only)
CREATE POLICY "Company owners can update their companies"
  ON psk_companies FOR UPDATE
  USING (auth.uid() = owner_id);
-- Delete companies (owner only)
CREATE POLICY "Company owners can delete their companies"
  ON psk_companies FOR DELETE
  USING (auth.uid() = owner_id);
-- ============================================================
-- NEW RLS POLICIES - Company Members
-- ============================================================

-- View members of companies user belongs to
CREATE POLICY "Users can view members of their companies"
  ON psk_company_members FOR SELECT
  USING (
    company_id IN (SELECT company_id FROM psk_company_members WHERE user_id = auth.uid())
  );
-- Insert handled by join function (security definer)
CREATE POLICY "System can add company members"
  ON psk_company_members FOR INSERT
  WITH CHECK (
    -- Owner adding themselves on company creation
    (auth.uid() = user_id AND role = 'owner')
  );
-- Only owners can delete members (except self-removal)
CREATE POLICY "Owners can remove members or members can leave"
  ON psk_company_members FOR DELETE
  USING (
    -- User removing themselves (leaving)
    auth.uid() = user_id
    OR
    -- Owner removing a member
    company_id IN (
      SELECT id FROM psk_companies WHERE owner_id = auth.uid()
    )
  );
-- ============================================================
-- NEW RLS POLICIES - Clients (personal OR company access)
-- ============================================================

CREATE POLICY "Users can view personal or company clients"
  ON psk_clients FOR SELECT
  USING (
    -- Personal clients (no company_id)
    (company_id IS NULL AND user_id = auth.uid())
    OR
    -- Company clients (user is member)
    (company_id IN (SELECT company_id FROM psk_company_members WHERE user_id = auth.uid()))
  );
CREATE POLICY "Users can create personal or company clients"
  ON psk_clients FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    AND (
      -- Personal client
      company_id IS NULL
      OR
      -- Company client (user must be member)
      company_id IN (SELECT company_id FROM psk_company_members WHERE user_id = auth.uid())
    )
  );
CREATE POLICY "Users can update personal or company clients"
  ON psk_clients FOR UPDATE
  USING (
    (company_id IS NULL AND user_id = auth.uid())
    OR
    (company_id IN (SELECT company_id FROM psk_company_members WHERE user_id = auth.uid()))
  );
CREATE POLICY "Users can delete personal or company clients"
  ON psk_clients FOR DELETE
  USING (
    (company_id IS NULL AND user_id = auth.uid())
    OR
    (company_id IN (SELECT company_id FROM psk_company_members WHERE user_id = auth.uid()))
  );
-- ============================================================
-- NEW RLS POLICIES - Projects (personal OR company access)
-- ============================================================

CREATE POLICY "Users can view personal or company projects"
  ON psk_projects FOR SELECT
  USING (
    (company_id IS NULL AND user_id = auth.uid())
    OR
    (company_id IN (SELECT company_id FROM psk_company_members WHERE user_id = auth.uid()))
  );
CREATE POLICY "Users can create personal or company projects"
  ON psk_projects FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    AND (
      company_id IS NULL
      OR
      company_id IN (SELECT company_id FROM psk_company_members WHERE user_id = auth.uid())
    )
  );
CREATE POLICY "Users can update personal or company projects"
  ON psk_projects FOR UPDATE
  USING (
    (company_id IS NULL AND user_id = auth.uid())
    OR
    (company_id IN (SELECT company_id FROM psk_company_members WHERE user_id = auth.uid()))
  );
CREATE POLICY "Users can delete personal or company projects"
  ON psk_projects FOR DELETE
  USING (
    (company_id IS NULL AND user_id = auth.uid())
    OR
    (company_id IN (SELECT company_id FROM psk_company_members WHERE user_id = auth.uid()))
  );
-- ============================================================
-- NEW RLS POLICIES - Tasks
-- Tasks inherit access from their project OR are personal daily tasks
-- ============================================================

CREATE POLICY "Users can view personal or company project tasks"
  ON psk_tasks FOR SELECT
  USING (
    -- Personal tasks (no project or personal project)
    user_id = auth.uid()
    OR
    -- Tasks in company projects
    project_id IN (
      SELECT id FROM psk_projects
      WHERE company_id IN (SELECT company_id FROM psk_company_members WHERE user_id = auth.uid())
    )
  );
CREATE POLICY "Users can create tasks"
  ON psk_tasks FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    AND (
      -- Personal task (no project)
      project_id IS NULL
      OR
      -- Task in own project
      project_id IN (SELECT id FROM psk_projects WHERE user_id = auth.uid())
      OR
      -- Task in company project
      project_id IN (
        SELECT id FROM psk_projects
        WHERE company_id IN (SELECT company_id FROM psk_company_members WHERE user_id = auth.uid())
      )
    )
  );
CREATE POLICY "Users can update personal or company project tasks"
  ON psk_tasks FOR UPDATE
  USING (
    user_id = auth.uid()
    OR
    project_id IN (
      SELECT id FROM psk_projects
      WHERE company_id IN (SELECT company_id FROM psk_company_members WHERE user_id = auth.uid())
    )
  );
CREATE POLICY "Users can delete personal or company project tasks"
  ON psk_tasks FOR DELETE
  USING (
    user_id = auth.uid()
    OR
    project_id IN (
      SELECT id FROM psk_projects
      WHERE company_id IN (SELECT company_id FROM psk_company_members WHERE user_id = auth.uid())
    )
  );
-- ============================================================
-- NEW RLS POLICIES - Time Entries (inherit from project)
-- ============================================================

CREATE POLICY "Users can view personal or company time entries"
  ON psk_time_entries FOR SELECT
  USING (
    user_id = auth.uid()
    OR
    project_id IN (
      SELECT id FROM psk_projects
      WHERE company_id IN (SELECT company_id FROM psk_company_members WHERE user_id = auth.uid())
    )
  );
CREATE POLICY "Users can create time entries"
  ON psk_time_entries FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    AND (
      project_id IN (SELECT id FROM psk_projects WHERE user_id = auth.uid())
      OR
      project_id IN (
        SELECT id FROM psk_projects
        WHERE company_id IN (SELECT company_id FROM psk_company_members WHERE user_id = auth.uid())
      )
    )
  );
CREATE POLICY "Users can update personal or company time entries"
  ON psk_time_entries FOR UPDATE
  USING (
    user_id = auth.uid()
    OR
    project_id IN (
      SELECT id FROM psk_projects
      WHERE company_id IN (SELECT company_id FROM psk_company_members WHERE user_id = auth.uid())
    )
  );
CREATE POLICY "Users can delete personal or company time entries"
  ON psk_time_entries FOR DELETE
  USING (
    user_id = auth.uid()
    OR
    project_id IN (
      SELECT id FROM psk_projects
      WHERE company_id IN (SELECT company_id FROM psk_company_members WHERE user_id = auth.uid())
    )
  );
-- ============================================================
-- NEW RLS POLICIES - Budget Line Items (inherit from project)
-- ============================================================

CREATE POLICY "Users can view personal or company budget items"
  ON psk_budget_line_items FOR SELECT
  USING (
    user_id = auth.uid()
    OR
    project_id IN (
      SELECT id FROM psk_projects
      WHERE company_id IN (SELECT company_id FROM psk_company_members WHERE user_id = auth.uid())
    )
  );
CREATE POLICY "Users can create budget items"
  ON psk_budget_line_items FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    AND (
      project_id IN (SELECT id FROM psk_projects WHERE user_id = auth.uid())
      OR
      project_id IN (
        SELECT id FROM psk_projects
        WHERE company_id IN (SELECT company_id FROM psk_company_members WHERE user_id = auth.uid())
      )
    )
  );
CREATE POLICY "Users can update personal or company budget items"
  ON psk_budget_line_items FOR UPDATE
  USING (
    user_id = auth.uid()
    OR
    project_id IN (
      SELECT id FROM psk_projects
      WHERE company_id IN (SELECT company_id FROM psk_company_members WHERE user_id = auth.uid())
    )
  );
CREATE POLICY "Users can delete personal or company budget items"
  ON psk_budget_line_items FOR DELETE
  USING (
    user_id = auth.uid()
    OR
    project_id IN (
      SELECT id FROM psk_projects
      WHERE company_id IN (SELECT company_id FROM psk_company_members WHERE user_id = auth.uid())
    )
  );
-- ============================================================
-- NEW RLS POLICIES - Files (inherit from project)
-- ============================================================

CREATE POLICY "Users can view personal or company files"
  ON psk_files FOR SELECT
  USING (
    user_id = auth.uid()
    OR
    project_id IN (
      SELECT id FROM psk_projects
      WHERE company_id IN (SELECT company_id FROM psk_company_members WHERE user_id = auth.uid())
    )
  );
CREATE POLICY "Users can create files"
  ON psk_files FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    AND (
      project_id IN (SELECT id FROM psk_projects WHERE user_id = auth.uid())
      OR
      project_id IN (
        SELECT id FROM psk_projects
        WHERE company_id IN (SELECT company_id FROM psk_company_members WHERE user_id = auth.uid())
      )
    )
  );
CREATE POLICY "Users can update personal or company files"
  ON psk_files FOR UPDATE
  USING (
    user_id = auth.uid()
    OR
    project_id IN (
      SELECT id FROM psk_projects
      WHERE company_id IN (SELECT company_id FROM psk_company_members WHERE user_id = auth.uid())
    )
  );
CREATE POLICY "Users can delete personal or company files"
  ON psk_files FOR DELETE
  USING (
    user_id = auth.uid()
    OR
    project_id IN (
      SELECT id FROM psk_projects
      WHERE company_id IN (SELECT company_id FROM psk_company_members WHERE user_id = auth.uid())
    )
  );
-- ============================================================
-- HELPER FUNCTIONS
-- ============================================================

-- Function to join a company by invite code
-- Returns the company_id on success, null if invalid code
CREATE OR REPLACE FUNCTION join_company_by_invite(invite_code_param UUID)
RETURNS UUID AS $$
DECLARE
  target_company_id UUID;
  existing_membership UUID;
BEGIN
  -- Find company by invite code
  SELECT id INTO target_company_id
  FROM psk_companies
  WHERE invite_code = invite_code_param;

  -- If no company found, return null
  IF target_company_id IS NULL THEN
    RETURN NULL;
  END IF;

  -- Check if user is already a member
  SELECT id INTO existing_membership
  FROM psk_company_members
  WHERE company_id = target_company_id AND user_id = auth.uid();

  -- If already a member, just return the company_id
  IF existing_membership IS NOT NULL THEN
    RETURN target_company_id;
  END IF;

  -- Add user as member
  INSERT INTO psk_company_members (company_id, user_id, role)
  VALUES (target_company_id, auth.uid(), 'member');

  RETURN target_company_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Function to regenerate invite code (owner only)
CREATE OR REPLACE FUNCTION regenerate_company_invite_code(company_id_param UUID)
RETURNS UUID AS $$
DECLARE
  new_code UUID;
BEGIN
  -- Check if user is owner
  IF NOT EXISTS (
    SELECT 1 FROM psk_companies
    WHERE id = company_id_param AND owner_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Only the company owner can regenerate the invite code';
  END IF;

  -- Generate new code
  new_code := gen_random_uuid();

  -- Update company
  UPDATE psk_companies
  SET invite_code = new_code, updated_at = now()
  WHERE id = company_id_param;

  RETURN new_code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Function to generate slug from company name
CREATE OR REPLACE FUNCTION generate_company_slug(company_name TEXT)
RETURNS TEXT AS $$
DECLARE
  base_slug TEXT;
  final_slug TEXT;
  counter INT := 0;
BEGIN
  -- Convert to lowercase, replace spaces with hyphens, remove special chars
  base_slug := lower(regexp_replace(company_name, '[^a-zA-Z0-9\s]', '', 'g'));
  base_slug := regexp_replace(base_slug, '\s+', '-', 'g');
  base_slug := trim(both '-' from base_slug);

  -- Start with base slug
  final_slug := base_slug;

  -- Check for uniqueness and add number if needed
  WHILE EXISTS (SELECT 1 FROM psk_companies WHERE slug = final_slug) LOOP
    counter := counter + 1;
    final_slug := base_slug || '-' || counter;
  END LOOP;

  RETURN final_slug;
END;
$$ LANGUAGE plpgsql;
-- ============================================================
-- TRIGGERS
-- ============================================================

-- Updated at trigger for companies
DROP TRIGGER IF EXISTS update_psk_companies_updated_at ON psk_companies;
CREATE TRIGGER update_psk_companies_updated_at
  BEFORE UPDATE ON psk_companies
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
-- Auto-populate created_by on insert for projects
CREATE OR REPLACE FUNCTION set_created_by()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.created_by IS NULL THEN
    NEW.created_by := auth.uid();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS set_psk_projects_created_by ON psk_projects;
CREATE TRIGGER set_psk_projects_created_by
  BEFORE INSERT ON psk_projects
  FOR EACH ROW
  EXECUTE FUNCTION set_created_by();
DROP TRIGGER IF EXISTS set_psk_tasks_created_by ON psk_tasks;
CREATE TRIGGER set_psk_tasks_created_by
  BEFORE INSERT ON psk_tasks
  FOR EACH ROW
  EXECUTE FUNCTION set_created_by();
DROP TRIGGER IF EXISTS set_psk_time_entries_created_by ON psk_time_entries;
CREATE TRIGGER set_psk_time_entries_created_by
  BEFORE INSERT ON psk_time_entries
  FOR EACH ROW
  EXECUTE FUNCTION set_created_by();
DROP TRIGGER IF EXISTS set_psk_budget_line_items_created_by ON psk_budget_line_items;
CREATE TRIGGER set_psk_budget_line_items_created_by
  BEFORE INSERT ON psk_budget_line_items
  FOR EACH ROW
  EXECUTE FUNCTION set_created_by();
DROP TRIGGER IF EXISTS set_psk_files_created_by ON psk_files;
CREATE TRIGGER set_psk_files_created_by
  BEFORE INSERT ON psk_files
  FOR EACH ROW
  EXECUTE FUNCTION set_created_by();
-- ============================================================
-- ENABLE REALTIME FOR COMPANY COLLABORATION
-- ============================================================

-- Enable realtime for company tables
ALTER PUBLICATION supabase_realtime ADD TABLE psk_companies;
ALTER PUBLICATION supabase_realtime ADD TABLE psk_company_members;
