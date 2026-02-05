-- Project Manager Tables Migration
-- PSK = Project SideKick

-- Clients table (must be created first due to foreign key reference)
CREATE TABLE IF NOT EXISTS psk_clients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  contacts JSONB DEFAULT '[]'::jsonb,
  logo TEXT,
  color_palette JSONB,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
-- Projects table
CREATE TABLE IF NOT EXISTS psk_projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  client_id UUID REFERENCES psk_clients(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  description TEXT,
  status TEXT DEFAULT 'backlog' CHECK (status IN ('backlog', 'in-progress', 'review', 'completed')),
  color TEXT,
  is_internal BOOLEAN DEFAULT false,
  is_archived BOOLEAN DEFAULT false,
  proton_drive_link TEXT,
  due_date TIMESTAMPTZ,
  notes TEXT,
  budget NUMERIC,
  hourly_rate NUMERIC,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
-- Tasks table
CREATE TABLE IF NOT EXISTS psk_tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  project_id UUID REFERENCES psk_projects(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  status TEXT DEFAULT 'todo' CHECK (status IN ('todo', 'in-progress', 'completed')),
  priority TEXT DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high')),
  due_date TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  is_daily BOOLEAN DEFAULT false,
  missed_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);
-- Time entries table
CREATE TABLE IF NOT EXISTS psk_time_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  project_id UUID NOT NULL REFERENCES psk_projects(id) ON DELETE CASCADE,
  description TEXT,
  duration INTEGER NOT NULL, -- minutes
  date DATE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);
-- Budget line items table
CREATE TABLE IF NOT EXISTS psk_budget_line_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  project_id UUID NOT NULL REFERENCES psk_projects(id) ON DELETE CASCADE,
  description TEXT NOT NULL,
  cost NUMERIC NOT NULL,
  category TEXT,
  date DATE,
  created_at TIMESTAMPTZ DEFAULT now()
);
-- Files table
CREATE TABLE IF NOT EXISTS psk_files (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  project_id UUID NOT NULL REFERENCES psk_projects(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  type TEXT,
  size INTEGER,
  url TEXT NOT NULL,
  uploaded_at TIMESTAMPTZ DEFAULT now()
);
-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_psk_projects_user_id ON psk_projects(user_id);
CREATE INDEX IF NOT EXISTS idx_psk_projects_client_id ON psk_projects(client_id);
CREATE INDEX IF NOT EXISTS idx_psk_projects_status ON psk_projects(status);
CREATE INDEX IF NOT EXISTS idx_psk_clients_user_id ON psk_clients(user_id);
CREATE INDEX IF NOT EXISTS idx_psk_tasks_user_id ON psk_tasks(user_id);
CREATE INDEX IF NOT EXISTS idx_psk_tasks_project_id ON psk_tasks(project_id);
CREATE INDEX IF NOT EXISTS idx_psk_tasks_status ON psk_tasks(status);
CREATE INDEX IF NOT EXISTS idx_psk_time_entries_user_id ON psk_time_entries(user_id);
CREATE INDEX IF NOT EXISTS idx_psk_time_entries_project_id ON psk_time_entries(project_id);
CREATE INDEX IF NOT EXISTS idx_psk_time_entries_date ON psk_time_entries(date);
CREATE INDEX IF NOT EXISTS idx_psk_budget_line_items_user_id ON psk_budget_line_items(user_id);
CREATE INDEX IF NOT EXISTS idx_psk_budget_line_items_project_id ON psk_budget_line_items(project_id);
CREATE INDEX IF NOT EXISTS idx_psk_files_user_id ON psk_files(user_id);
CREATE INDEX IF NOT EXISTS idx_psk_files_project_id ON psk_files(project_id);
-- Enable Row Level Security
ALTER TABLE psk_clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE psk_projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE psk_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE psk_time_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE psk_budget_line_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE psk_files ENABLE ROW LEVEL SECURITY;
-- RLS Policies for psk_clients
CREATE POLICY "Users can view their own clients"
  ON psk_clients FOR SELECT
  USING (auth.uid() = user_id);
CREATE POLICY "Users can create their own clients"
  ON psk_clients FOR INSERT
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own clients"
  ON psk_clients FOR UPDATE
  USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own clients"
  ON psk_clients FOR DELETE
  USING (auth.uid() = user_id);
-- RLS Policies for psk_projects
CREATE POLICY "Users can view their own projects"
  ON psk_projects FOR SELECT
  USING (auth.uid() = user_id);
CREATE POLICY "Users can create their own projects"
  ON psk_projects FOR INSERT
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own projects"
  ON psk_projects FOR UPDATE
  USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own projects"
  ON psk_projects FOR DELETE
  USING (auth.uid() = user_id);
-- RLS Policies for psk_tasks
CREATE POLICY "Users can view their own tasks"
  ON psk_tasks FOR SELECT
  USING (auth.uid() = user_id);
CREATE POLICY "Users can create their own tasks"
  ON psk_tasks FOR INSERT
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own tasks"
  ON psk_tasks FOR UPDATE
  USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own tasks"
  ON psk_tasks FOR DELETE
  USING (auth.uid() = user_id);
-- RLS Policies for psk_time_entries
CREATE POLICY "Users can view their own time entries"
  ON psk_time_entries FOR SELECT
  USING (auth.uid() = user_id);
CREATE POLICY "Users can create their own time entries"
  ON psk_time_entries FOR INSERT
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own time entries"
  ON psk_time_entries FOR UPDATE
  USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own time entries"
  ON psk_time_entries FOR DELETE
  USING (auth.uid() = user_id);
-- RLS Policies for psk_budget_line_items
CREATE POLICY "Users can view their own budget items"
  ON psk_budget_line_items FOR SELECT
  USING (auth.uid() = user_id);
CREATE POLICY "Users can create their own budget items"
  ON psk_budget_line_items FOR INSERT
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own budget items"
  ON psk_budget_line_items FOR UPDATE
  USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own budget items"
  ON psk_budget_line_items FOR DELETE
  USING (auth.uid() = user_id);
-- RLS Policies for psk_files
CREATE POLICY "Users can view their own files"
  ON psk_files FOR SELECT
  USING (auth.uid() = user_id);
CREATE POLICY "Users can create their own files"
  ON psk_files FOR INSERT
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own files"
  ON psk_files FOR UPDATE
  USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own files"
  ON psk_files FOR DELETE
  USING (auth.uid() = user_id);
-- Updated at trigger function (if not exists)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';
-- Add updated_at triggers
DROP TRIGGER IF EXISTS update_psk_clients_updated_at ON psk_clients;
CREATE TRIGGER update_psk_clients_updated_at
    BEFORE UPDATE ON psk_clients
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
DROP TRIGGER IF EXISTS update_psk_projects_updated_at ON psk_projects;
CREATE TRIGGER update_psk_projects_updated_at
    BEFORE UPDATE ON psk_projects
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
