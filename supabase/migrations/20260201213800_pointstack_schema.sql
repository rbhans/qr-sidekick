-- PointStack Community Platform Schema Migration
-- ============================================================
-- Complete schema for the PointStack community platform
-- Includes: profiles extensions, companies, posts, projects,
-- jobs, resources, messaging, notifications
-- ============================================================

-- ============================================================
-- PROFILE EXTENSIONS
-- ============================================================

-- Add new columns to profiles table
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS skills TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS headline TEXT,
  ADD COLUMN IF NOT EXISTS location TEXT,
  ADD COLUMN IF NOT EXISTS website_url TEXT,
  ADD COLUMN IF NOT EXISTS linkedin_url TEXT,
  ADD COLUMN IF NOT EXISTS github_url TEXT,
  ADD COLUMN IF NOT EXISTS availability_status TEXT DEFAULT 'not-looking' CHECK (availability_status IN ('available', 'busy', 'not-looking')),
  ADD COLUMN IF NOT EXISTS reputation_score INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN DEFAULT false;
-- Index for skills array search
CREATE INDEX IF NOT EXISTS idx_profiles_skills ON public.profiles USING GIN (skills);
-- Index for availability status
CREATE INDEX IF NOT EXISTS idx_profiles_availability ON public.profiles (availability_status) WHERE availability_status = 'available';
-- Index for reputation leaderboard
CREATE INDEX IF NOT EXISTS idx_profiles_reputation ON public.profiles (reputation_score DESC);
-- ============================================================
-- COMPANIES
-- ============================================================

CREATE TABLE IF NOT EXISTS public.pointstack_companies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  logo_url TEXT,
  description TEXT,
  website_url TEXT,
  location TEXT,
  size_range TEXT CHECK (size_range IN ('1-10', '11-50', '51-200', '201-500', '500+')),
  industry TEXT,
  owner_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  is_verified BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
-- Enable RLS
ALTER TABLE public.pointstack_companies ENABLE ROW LEVEL SECURITY;
-- RLS Policies
CREATE POLICY "Companies are viewable by everyone"
  ON public.pointstack_companies FOR SELECT
  USING (true);
CREATE POLICY "Authenticated users can create companies"
  ON public.pointstack_companies FOR INSERT
  WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Owners can update their companies"
  ON public.pointstack_companies FOR UPDATE
  USING (auth.uid() = owner_id);
CREATE POLICY "Owners can delete their companies"
  ON public.pointstack_companies FOR DELETE
  USING (auth.uid() = owner_id);
-- Indexes
CREATE INDEX IF NOT EXISTS idx_pointstack_companies_slug ON public.pointstack_companies (slug);
CREATE INDEX IF NOT EXISTS idx_pointstack_companies_owner ON public.pointstack_companies (owner_id);
-- ============================================================
-- COMPANY MEMBERS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.pointstack_company_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES public.pointstack_companies(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  role TEXT DEFAULT 'member' CHECK (role IN ('owner', 'admin', 'member')),
  title TEXT,
  joined_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (company_id, user_id)
);
-- Enable RLS
ALTER TABLE public.pointstack_company_members ENABLE ROW LEVEL SECURITY;
-- RLS Policies
CREATE POLICY "Company members are viewable by everyone"
  ON public.pointstack_company_members FOR SELECT
  USING (true);
CREATE POLICY "Company owners/admins can add members"
  ON public.pointstack_company_members FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.pointstack_company_members cm
      WHERE cm.company_id = pointstack_company_members.company_id
        AND cm.user_id = auth.uid()
        AND cm.role IN ('owner', 'admin')
    )
    OR
    EXISTS (
      SELECT 1 FROM public.pointstack_companies c
      WHERE c.id = pointstack_company_members.company_id
        AND c.owner_id = auth.uid()
    )
  );
CREATE POLICY "Company owners/admins can update members"
  ON public.pointstack_company_members FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.pointstack_company_members cm
      WHERE cm.company_id = pointstack_company_members.company_id
        AND cm.user_id = auth.uid()
        AND cm.role IN ('owner', 'admin')
    )
  );
CREATE POLICY "Company owners/admins can remove members"
  ON public.pointstack_company_members FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.pointstack_company_members cm
      WHERE cm.company_id = pointstack_company_members.company_id
        AND cm.user_id = auth.uid()
        AND cm.role IN ('owner', 'admin')
    )
    OR auth.uid() = user_id -- Users can leave companies
  );
-- Indexes
CREATE INDEX IF NOT EXISTS idx_pointstack_company_members_company ON public.pointstack_company_members (company_id);
CREATE INDEX IF NOT EXISTS idx_pointstack_company_members_user ON public.pointstack_company_members (user_id);
-- ============================================================
-- USER FOLLOWS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.pointstack_user_follows (
  follower_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  following_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (follower_id, following_id),
  CHECK (follower_id != following_id)
);
-- Enable RLS
ALTER TABLE public.pointstack_user_follows ENABLE ROW LEVEL SECURITY;
-- RLS Policies
CREATE POLICY "Follows are viewable by everyone"
  ON public.pointstack_user_follows FOR SELECT
  USING (true);
CREATE POLICY "Users can follow others"
  ON public.pointstack_user_follows FOR INSERT
  WITH CHECK (auth.uid() = follower_id);
CREATE POLICY "Users can unfollow"
  ON public.pointstack_user_follows FOR DELETE
  USING (auth.uid() = follower_id);
-- Indexes
CREATE INDEX IF NOT EXISTS idx_pointstack_user_follows_follower ON public.pointstack_user_follows (follower_id);
CREATE INDEX IF NOT EXISTS idx_pointstack_user_follows_following ON public.pointstack_user_follows (following_id);
-- ============================================================
-- POSTS (Unified Content)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.pointstack_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  post_type TEXT NOT NULL CHECK (post_type IN ('discussion', 'question', 'project', 'job', 'tip')),
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  is_published BOOLEAN DEFAULT true,
  is_pinned BOOLEAN DEFAULT false,
  view_count INT DEFAULT 0,
  upvote_count INT DEFAULT 0,
  comment_count INT DEFAULT 0,
  tags TEXT[] DEFAULT '{}',
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
-- Enable RLS
ALTER TABLE public.pointstack_posts ENABLE ROW LEVEL SECURITY;
-- RLS Policies
CREATE POLICY "Published posts are viewable by everyone"
  ON public.pointstack_posts FOR SELECT
  USING (is_published = true OR auth.uid() = author_id);
CREATE POLICY "Authenticated users can create posts"
  ON public.pointstack_posts FOR INSERT
  WITH CHECK (auth.uid() = author_id);
CREATE POLICY "Authors can update their posts"
  ON public.pointstack_posts FOR UPDATE
  USING (auth.uid() = author_id);
CREATE POLICY "Authors can delete their posts"
  ON public.pointstack_posts FOR DELETE
  USING (auth.uid() = author_id);
-- Indexes
CREATE INDEX IF NOT EXISTS idx_pointstack_posts_author ON public.pointstack_posts (author_id);
CREATE INDEX IF NOT EXISTS idx_pointstack_posts_type ON public.pointstack_posts (post_type);
CREATE INDEX IF NOT EXISTS idx_pointstack_posts_slug ON public.pointstack_posts (slug);
CREATE INDEX IF NOT EXISTS idx_pointstack_posts_tags ON public.pointstack_posts USING GIN (tags);
CREATE INDEX IF NOT EXISTS idx_pointstack_posts_created ON public.pointstack_posts (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_pointstack_posts_upvotes ON public.pointstack_posts (upvote_count DESC);
-- ============================================================
-- POST VOTES
-- ============================================================

CREATE TABLE IF NOT EXISTS public.pointstack_post_votes (
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  post_id UUID REFERENCES public.pointstack_posts(id) ON DELETE CASCADE NOT NULL,
  vote_type INT NOT NULL CHECK (vote_type IN (1, -1)),
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (user_id, post_id)
);
-- Enable RLS
ALTER TABLE public.pointstack_post_votes ENABLE ROW LEVEL SECURITY;
-- RLS Policies
CREATE POLICY "Votes are viewable by everyone"
  ON public.pointstack_post_votes FOR SELECT
  USING (true);
CREATE POLICY "Authenticated users can vote"
  ON public.pointstack_post_votes FOR INSERT
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their votes"
  ON public.pointstack_post_votes FOR UPDATE
  USING (auth.uid() = user_id);
CREATE POLICY "Users can remove their votes"
  ON public.pointstack_post_votes FOR DELETE
  USING (auth.uid() = user_id);
-- Indexes
CREATE INDEX IF NOT EXISTS idx_pointstack_post_votes_post ON public.pointstack_post_votes (post_id);
-- ============================================================
-- POST COMMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.pointstack_post_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID REFERENCES public.pointstack_posts(id) ON DELETE CASCADE NOT NULL,
  author_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  parent_id UUID REFERENCES public.pointstack_post_comments(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  is_accepted BOOLEAN DEFAULT false,
  upvote_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
-- Enable RLS
ALTER TABLE public.pointstack_post_comments ENABLE ROW LEVEL SECURITY;
-- RLS Policies
CREATE POLICY "Comments are viewable by everyone"
  ON public.pointstack_post_comments FOR SELECT
  USING (true);
CREATE POLICY "Authenticated users can create comments"
  ON public.pointstack_post_comments FOR INSERT
  WITH CHECK (auth.uid() = author_id);
CREATE POLICY "Authors can update their comments"
  ON public.pointstack_post_comments FOR UPDATE
  USING (auth.uid() = author_id);
CREATE POLICY "Authors can delete their comments"
  ON public.pointstack_post_comments FOR DELETE
  USING (auth.uid() = author_id);
-- Indexes
CREATE INDEX IF NOT EXISTS idx_pointstack_post_comments_post ON public.pointstack_post_comments (post_id);
CREATE INDEX IF NOT EXISTS idx_pointstack_post_comments_author ON public.pointstack_post_comments (author_id);
CREATE INDEX IF NOT EXISTS idx_pointstack_post_comments_parent ON public.pointstack_post_comments (parent_id);
-- ============================================================
-- COMMENT VOTES
-- ============================================================

CREATE TABLE IF NOT EXISTS public.pointstack_comment_votes (
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  comment_id UUID REFERENCES public.pointstack_post_comments(id) ON DELETE CASCADE NOT NULL,
  vote_type INT NOT NULL CHECK (vote_type IN (1, -1)),
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (user_id, comment_id)
);
-- Enable RLS
ALTER TABLE public.pointstack_comment_votes ENABLE ROW LEVEL SECURITY;
-- RLS Policies
CREATE POLICY "Comment votes are viewable by everyone"
  ON public.pointstack_comment_votes FOR SELECT
  USING (true);
CREATE POLICY "Authenticated users can vote on comments"
  ON public.pointstack_comment_votes FOR INSERT
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their comment votes"
  ON public.pointstack_comment_votes FOR UPDATE
  USING (auth.uid() = user_id);
CREATE POLICY "Users can remove their comment votes"
  ON public.pointstack_comment_votes FOR DELETE
  USING (auth.uid() = user_id);
-- Indexes
CREATE INDEX IF NOT EXISTS idx_pointstack_comment_votes_comment ON public.pointstack_comment_votes (comment_id);
-- ============================================================
-- SHOWCASE PROJECTS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.pointstack_showcase_projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  company_id UUID REFERENCES public.pointstack_companies(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  description TEXT,
  content TEXT,
  cover_image_url TEXT,
  images TEXT[] DEFAULT '{}',
  building_types TEXT[] DEFAULT '{}',
  systems TEXT[] DEFAULT '{}',
  technologies TEXT[] DEFAULT '{}',
  location TEXT,
  completion_date DATE,
  square_footage INT,
  is_featured BOOLEAN DEFAULT false,
  view_count INT DEFAULT 0,
  like_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
-- Enable RLS
ALTER TABLE public.pointstack_showcase_projects ENABLE ROW LEVEL SECURITY;
-- RLS Policies
CREATE POLICY "Showcase projects are viewable by everyone"
  ON public.pointstack_showcase_projects FOR SELECT
  USING (true);
CREATE POLICY "Authenticated users can create showcase projects"
  ON public.pointstack_showcase_projects FOR INSERT
  WITH CHECK (auth.uid() = author_id);
CREATE POLICY "Authors can update their showcase projects"
  ON public.pointstack_showcase_projects FOR UPDATE
  USING (auth.uid() = author_id);
CREATE POLICY "Authors can delete their showcase projects"
  ON public.pointstack_showcase_projects FOR DELETE
  USING (auth.uid() = author_id);
-- Indexes
CREATE INDEX IF NOT EXISTS idx_pointstack_showcase_author ON public.pointstack_showcase_projects (author_id);
CREATE INDEX IF NOT EXISTS idx_pointstack_showcase_company ON public.pointstack_showcase_projects (company_id);
CREATE INDEX IF NOT EXISTS idx_pointstack_showcase_slug ON public.pointstack_showcase_projects (slug);
CREATE INDEX IF NOT EXISTS idx_pointstack_showcase_featured ON public.pointstack_showcase_projects (is_featured) WHERE is_featured = true;
CREATE INDEX IF NOT EXISTS idx_pointstack_showcase_building_types ON public.pointstack_showcase_projects USING GIN (building_types);
CREATE INDEX IF NOT EXISTS idx_pointstack_showcase_systems ON public.pointstack_showcase_projects USING GIN (systems);
CREATE INDEX IF NOT EXISTS idx_pointstack_showcase_technologies ON public.pointstack_showcase_projects USING GIN (technologies);
-- ============================================================
-- PROJECT CREDITS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.pointstack_project_credits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID REFERENCES public.pointstack_showcase_projects(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  role TEXT NOT NULL,
  display_name TEXT,
  UNIQUE (project_id, user_id)
);
-- Enable RLS
ALTER TABLE public.pointstack_project_credits ENABLE ROW LEVEL SECURITY;
-- RLS Policies
CREATE POLICY "Project credits are viewable by everyone"
  ON public.pointstack_project_credits FOR SELECT
  USING (true);
CREATE POLICY "Project authors can manage credits"
  ON public.pointstack_project_credits FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.pointstack_showcase_projects p
      WHERE p.id = pointstack_project_credits.project_id
        AND p.author_id = auth.uid()
    )
  );
CREATE POLICY "Project authors can update credits"
  ON public.pointstack_project_credits FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.pointstack_showcase_projects p
      WHERE p.id = project_id AND p.author_id = auth.uid()
    )
  );
CREATE POLICY "Project authors can delete credits"
  ON public.pointstack_project_credits FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.pointstack_showcase_projects p
      WHERE p.id = project_id AND p.author_id = auth.uid()
    )
  );
-- Indexes
CREATE INDEX IF NOT EXISTS idx_pointstack_project_credits_project ON public.pointstack_project_credits (project_id);
CREATE INDEX IF NOT EXISTS idx_pointstack_project_credits_user ON public.pointstack_project_credits (user_id);
-- ============================================================
-- PROJECT LIKES
-- ============================================================

CREATE TABLE IF NOT EXISTS public.pointstack_project_likes (
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  project_id UUID REFERENCES public.pointstack_showcase_projects(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (user_id, project_id)
);
-- Enable RLS
ALTER TABLE public.pointstack_project_likes ENABLE ROW LEVEL SECURITY;
-- RLS Policies
CREATE POLICY "Project likes are viewable by everyone"
  ON public.pointstack_project_likes FOR SELECT
  USING (true);
CREATE POLICY "Authenticated users can like projects"
  ON public.pointstack_project_likes FOR INSERT
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can remove their likes"
  ON public.pointstack_project_likes FOR DELETE
  USING (auth.uid() = user_id);
-- Indexes
CREATE INDEX IF NOT EXISTS idx_pointstack_project_likes_project ON public.pointstack_project_likes (project_id);
-- ============================================================
-- JOBS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.pointstack_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES public.pointstack_companies(id) ON DELETE CASCADE,
  posted_by UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  description TEXT NOT NULL,
  requirements TEXT,
  job_type TEXT NOT NULL CHECK (job_type IN ('full-time', 'part-time', 'contract', 'freelance', 'internship')),
  experience_level TEXT CHECK (experience_level IN ('entry', 'mid', 'senior', 'lead', 'executive')),
  location TEXT,
  is_remote BOOLEAN DEFAULT false,
  salary_min INT,
  salary_max INT,
  salary_currency TEXT DEFAULT 'USD',
  application_url TEXT,
  application_email TEXT,
  is_active BOOLEAN DEFAULT true,
  expires_at TIMESTAMPTZ,
  view_count INT DEFAULT 0,
  application_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
-- Enable RLS
ALTER TABLE public.pointstack_jobs ENABLE ROW LEVEL SECURITY;
-- RLS Policies
CREATE POLICY "Active jobs are viewable by everyone"
  ON public.pointstack_jobs FOR SELECT
  USING (is_active = true OR auth.uid() = posted_by);
CREATE POLICY "Authenticated users can create jobs"
  ON public.pointstack_jobs FOR INSERT
  WITH CHECK (auth.uid() = posted_by);
CREATE POLICY "Posters can update their jobs"
  ON public.pointstack_jobs FOR UPDATE
  USING (auth.uid() = posted_by);
CREATE POLICY "Posters can delete their jobs"
  ON public.pointstack_jobs FOR DELETE
  USING (auth.uid() = posted_by);
-- Indexes
CREATE INDEX IF NOT EXISTS idx_pointstack_jobs_company ON public.pointstack_jobs (company_id);
CREATE INDEX IF NOT EXISTS idx_pointstack_jobs_posted_by ON public.pointstack_jobs (posted_by);
CREATE INDEX IF NOT EXISTS idx_pointstack_jobs_slug ON public.pointstack_jobs (slug);
CREATE INDEX IF NOT EXISTS idx_pointstack_jobs_type ON public.pointstack_jobs (job_type);
CREATE INDEX IF NOT EXISTS idx_pointstack_jobs_active ON public.pointstack_jobs (is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_pointstack_jobs_created ON public.pointstack_jobs (created_at DESC);
-- ============================================================
-- JOB APPLICATIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.pointstack_job_applications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id UUID REFERENCES public.pointstack_jobs(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  cover_letter TEXT,
  resume_url TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'interviewing', 'rejected', 'accepted')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (job_id, user_id)
);
-- Enable RLS
ALTER TABLE public.pointstack_job_applications ENABLE ROW LEVEL SECURITY;
-- RLS Policies
CREATE POLICY "Users can view their own applications"
  ON public.pointstack_job_applications FOR SELECT
  USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM public.pointstack_jobs j
      WHERE j.id = job_id AND j.posted_by = auth.uid()
    )
  );
CREATE POLICY "Authenticated users can apply"
  ON public.pointstack_job_applications FOR INSERT
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their applications"
  ON public.pointstack_job_applications FOR UPDATE
  USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM public.pointstack_jobs j
      WHERE j.id = job_id AND j.posted_by = auth.uid()
    )
  );
CREATE POLICY "Users can withdraw their applications"
  ON public.pointstack_job_applications FOR DELETE
  USING (auth.uid() = user_id);
-- Indexes
CREATE INDEX IF NOT EXISTS idx_pointstack_job_applications_job ON public.pointstack_job_applications (job_id);
CREATE INDEX IF NOT EXISTS idx_pointstack_job_applications_user ON public.pointstack_job_applications (user_id);
CREATE INDEX IF NOT EXISTS idx_pointstack_job_applications_status ON public.pointstack_job_applications (status);
-- ============================================================
-- RESOURCE LISTINGS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.pointstack_resource_listings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  description TEXT,
  category TEXT NOT NULL CHECK (category IN ('template', 'script', 'document', 'guide', 'tool', 'other')),
  preview_images TEXT[] DEFAULT '{}',
  file_url TEXT,
  is_free BOOLEAN DEFAULT true,
  external_link TEXT,
  download_count INT DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
-- Enable RLS
ALTER TABLE public.pointstack_resource_listings ENABLE ROW LEVEL SECURITY;
-- RLS Policies
CREATE POLICY "Active resources are viewable by everyone"
  ON public.pointstack_resource_listings FOR SELECT
  USING (is_active = true OR auth.uid() = author_id);
CREATE POLICY "Authenticated users can create resources"
  ON public.pointstack_resource_listings FOR INSERT
  WITH CHECK (auth.uid() = author_id);
CREATE POLICY "Authors can update their resources"
  ON public.pointstack_resource_listings FOR UPDATE
  USING (auth.uid() = author_id);
CREATE POLICY "Authors can delete their resources"
  ON public.pointstack_resource_listings FOR DELETE
  USING (auth.uid() = author_id);
-- Indexes
CREATE INDEX IF NOT EXISTS idx_pointstack_resources_author ON public.pointstack_resource_listings (author_id);
CREATE INDEX IF NOT EXISTS idx_pointstack_resources_slug ON public.pointstack_resource_listings (slug);
CREATE INDEX IF NOT EXISTS idx_pointstack_resources_category ON public.pointstack_resource_listings (category);
CREATE INDEX IF NOT EXISTS idx_pointstack_resources_active ON public.pointstack_resource_listings (is_active) WHERE is_active = true;
-- ============================================================
-- NOTIFICATIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.pointstack_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('mention', 'reply', 'follow', 'like', 'answer_accepted', 'job_application', 'system')),
  title TEXT NOT NULL,
  body TEXT,
  link TEXT,
  is_read BOOLEAN DEFAULT false,
  actor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now()
);
-- Enable RLS
ALTER TABLE public.pointstack_notifications ENABLE ROW LEVEL SECURITY;
-- RLS Policies
CREATE POLICY "Users can view their own notifications"
  ON public.pointstack_notifications FOR SELECT
  USING (auth.uid() = user_id);
CREATE POLICY "System can create notifications"
  ON public.pointstack_notifications FOR INSERT
  WITH CHECK (true);
CREATE POLICY "Users can update their notifications"
  ON public.pointstack_notifications FOR UPDATE
  USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their notifications"
  ON public.pointstack_notifications FOR DELETE
  USING (auth.uid() = user_id);
-- Indexes
CREATE INDEX IF NOT EXISTS idx_pointstack_notifications_user ON public.pointstack_notifications (user_id);
CREATE INDEX IF NOT EXISTS idx_pointstack_notifications_unread ON public.pointstack_notifications (user_id, is_read) WHERE is_read = false;
CREATE INDEX IF NOT EXISTS idx_pointstack_notifications_created ON public.pointstack_notifications (created_at DESC);
-- ============================================================
-- NOTIFICATION PREFERENCES
-- ============================================================

CREATE TABLE IF NOT EXISTS public.pointstack_notification_preferences (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  email_mentions BOOLEAN DEFAULT true,
  email_replies BOOLEAN DEFAULT true,
  email_follows BOOLEAN DEFAULT true,
  email_digest_frequency TEXT DEFAULT 'daily' CHECK (email_digest_frequency IN ('never', 'daily', 'weekly')),
  push_enabled BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
-- Enable RLS
ALTER TABLE public.pointstack_notification_preferences ENABLE ROW LEVEL SECURITY;
-- RLS Policies
CREATE POLICY "Users can view their own preferences"
  ON public.pointstack_notification_preferences FOR SELECT
  USING (auth.uid() = user_id);
CREATE POLICY "Users can create their preferences"
  ON public.pointstack_notification_preferences FOR INSERT
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their preferences"
  ON public.pointstack_notification_preferences FOR UPDATE
  USING (auth.uid() = user_id);
-- ============================================================
-- CONVERSATIONS (Direct Messaging)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.pointstack_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
-- Enable RLS
ALTER TABLE public.pointstack_conversations ENABLE ROW LEVEL SECURITY;
-- Note: RLS policy for conversations is created after participants table

-- ============================================================
-- CONVERSATION PARTICIPANTS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.pointstack_conversation_participants (
  conversation_id UUID REFERENCES public.pointstack_conversations(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  last_read_at TIMESTAMPTZ,
  is_muted BOOLEAN DEFAULT false,
  PRIMARY KEY (conversation_id, user_id)
);
-- Enable RLS
ALTER TABLE public.pointstack_conversation_participants ENABLE ROW LEVEL SECURITY;
-- RLS Policies
CREATE POLICY "Users can view their participations"
  ON public.pointstack_conversation_participants FOR SELECT
  USING (auth.uid() = user_id);
CREATE POLICY "Users can update their participation"
  ON public.pointstack_conversation_participants FOR UPDATE
  USING (auth.uid() = user_id);
-- Indexes
CREATE INDEX IF NOT EXISTS idx_pointstack_conv_participants_user ON public.pointstack_conversation_participants (user_id);
-- RLS Policy for conversations (created after participants table)
CREATE POLICY "Participants can view conversations"
  ON public.pointstack_conversations FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.pointstack_conversation_participants cp
      WHERE cp.conversation_id = id AND cp.user_id = auth.uid()
    )
  );
-- ============================================================
-- MESSAGES
-- ============================================================

CREATE TABLE IF NOT EXISTS public.pointstack_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID REFERENCES public.pointstack_conversations(id) ON DELETE CASCADE NOT NULL,
  sender_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  content TEXT NOT NULL,
  is_edited BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
-- Enable RLS
ALTER TABLE public.pointstack_messages ENABLE ROW LEVEL SECURITY;
-- RLS Policies
CREATE POLICY "Participants can view messages"
  ON public.pointstack_messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.pointstack_conversation_participants cp
      WHERE cp.conversation_id = pointstack_messages.conversation_id AND cp.user_id = auth.uid()
    )
  );
CREATE POLICY "Participants can send messages"
  ON public.pointstack_messages FOR INSERT
  WITH CHECK (
    auth.uid() = sender_id
    AND EXISTS (
      SELECT 1 FROM public.pointstack_conversation_participants cp
      WHERE cp.conversation_id = pointstack_messages.conversation_id AND cp.user_id = auth.uid()
    )
  );
CREATE POLICY "Senders can edit their messages"
  ON public.pointstack_messages FOR UPDATE
  USING (auth.uid() = sender_id);
CREATE POLICY "Senders can delete their messages"
  ON public.pointstack_messages FOR DELETE
  USING (auth.uid() = sender_id);
-- Indexes
CREATE INDEX IF NOT EXISTS idx_pointstack_messages_conversation ON public.pointstack_messages (conversation_id);
CREATE INDEX IF NOT EXISTS idx_pointstack_messages_created ON public.pointstack_messages (created_at DESC);
-- ============================================================
-- MESSAGE REQUESTS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.pointstack_message_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  to_user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  message TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined')),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (from_user_id, to_user_id)
);
-- Enable RLS
ALTER TABLE public.pointstack_message_requests ENABLE ROW LEVEL SECURITY;
-- RLS Policies
CREATE POLICY "Users can view their message requests"
  ON public.pointstack_message_requests FOR SELECT
  USING (auth.uid() = from_user_id OR auth.uid() = to_user_id);
CREATE POLICY "Users can create message requests"
  ON public.pointstack_message_requests FOR INSERT
  WITH CHECK (auth.uid() = from_user_id);
CREATE POLICY "Recipients can update message requests"
  ON public.pointstack_message_requests FOR UPDATE
  USING (auth.uid() = to_user_id);
CREATE POLICY "Users can delete their sent requests"
  ON public.pointstack_message_requests FOR DELETE
  USING (auth.uid() = from_user_id);
-- Indexes
CREATE INDEX IF NOT EXISTS idx_pointstack_message_requests_to ON public.pointstack_message_requests (to_user_id);
CREATE INDEX IF NOT EXISTS idx_pointstack_message_requests_pending ON public.pointstack_message_requests (to_user_id, status) WHERE status = 'pending';
-- ============================================================
-- TRIGGERS & FUNCTIONS
-- ============================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.pointstack_update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
-- Apply updated_at triggers
CREATE TRIGGER pointstack_companies_updated_at
  BEFORE UPDATE ON public.pointstack_companies
  FOR EACH ROW EXECUTE FUNCTION public.pointstack_update_timestamp();
CREATE TRIGGER pointstack_posts_updated_at
  BEFORE UPDATE ON public.pointstack_posts
  FOR EACH ROW EXECUTE FUNCTION public.pointstack_update_timestamp();
CREATE TRIGGER pointstack_post_comments_updated_at
  BEFORE UPDATE ON public.pointstack_post_comments
  FOR EACH ROW EXECUTE FUNCTION public.pointstack_update_timestamp();
CREATE TRIGGER pointstack_showcase_projects_updated_at
  BEFORE UPDATE ON public.pointstack_showcase_projects
  FOR EACH ROW EXECUTE FUNCTION public.pointstack_update_timestamp();
CREATE TRIGGER pointstack_jobs_updated_at
  BEFORE UPDATE ON public.pointstack_jobs
  FOR EACH ROW EXECUTE FUNCTION public.pointstack_update_timestamp();
CREATE TRIGGER pointstack_job_applications_updated_at
  BEFORE UPDATE ON public.pointstack_job_applications
  FOR EACH ROW EXECUTE FUNCTION public.pointstack_update_timestamp();
CREATE TRIGGER pointstack_resource_listings_updated_at
  BEFORE UPDATE ON public.pointstack_resource_listings
  FOR EACH ROW EXECUTE FUNCTION public.pointstack_update_timestamp();
CREATE TRIGGER pointstack_notification_preferences_updated_at
  BEFORE UPDATE ON public.pointstack_notification_preferences
  FOR EACH ROW EXECUTE FUNCTION public.pointstack_update_timestamp();
CREATE TRIGGER pointstack_conversations_updated_at
  BEFORE UPDATE ON public.pointstack_conversations
  FOR EACH ROW EXECUTE FUNCTION public.pointstack_update_timestamp();
CREATE TRIGGER pointstack_messages_updated_at
  BEFORE UPDATE ON public.pointstack_messages
  FOR EACH ROW EXECUTE FUNCTION public.pointstack_update_timestamp();
-- Function to update post upvote count
CREATE OR REPLACE FUNCTION public.pointstack_update_post_upvote_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.pointstack_posts
    SET upvote_count = upvote_count + NEW.vote_type
    WHERE id = NEW.post_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.pointstack_posts
    SET upvote_count = upvote_count - OLD.vote_type
    WHERE id = OLD.post_id;
  ELSIF TG_OP = 'UPDATE' THEN
    UPDATE public.pointstack_posts
    SET upvote_count = upvote_count - OLD.vote_type + NEW.vote_type
    WHERE id = NEW.post_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
CREATE TRIGGER pointstack_post_vote_change
  AFTER INSERT OR UPDATE OR DELETE ON public.pointstack_post_votes
  FOR EACH ROW EXECUTE FUNCTION public.pointstack_update_post_upvote_count();
-- Function to update post comment count
CREATE OR REPLACE FUNCTION public.pointstack_update_post_comment_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.pointstack_posts
    SET comment_count = comment_count + 1
    WHERE id = NEW.post_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.pointstack_posts
    SET comment_count = GREATEST(0, comment_count - 1)
    WHERE id = OLD.post_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
CREATE TRIGGER pointstack_post_comment_change
  AFTER INSERT OR DELETE ON public.pointstack_post_comments
  FOR EACH ROW EXECUTE FUNCTION public.pointstack_update_post_comment_count();
-- Function to update comment upvote count
CREATE OR REPLACE FUNCTION public.pointstack_update_comment_upvote_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.pointstack_post_comments
    SET upvote_count = upvote_count + NEW.vote_type
    WHERE id = NEW.comment_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.pointstack_post_comments
    SET upvote_count = upvote_count - OLD.vote_type
    WHERE id = OLD.comment_id;
  ELSIF TG_OP = 'UPDATE' THEN
    UPDATE public.pointstack_post_comments
    SET upvote_count = upvote_count - OLD.vote_type + NEW.vote_type
    WHERE id = NEW.comment_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
CREATE TRIGGER pointstack_comment_vote_change
  AFTER INSERT OR UPDATE OR DELETE ON public.pointstack_comment_votes
  FOR EACH ROW EXECUTE FUNCTION public.pointstack_update_comment_upvote_count();
-- Function to update project like count
CREATE OR REPLACE FUNCTION public.pointstack_update_project_like_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.pointstack_showcase_projects
    SET like_count = like_count + 1
    WHERE id = NEW.project_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.pointstack_showcase_projects
    SET like_count = GREATEST(0, like_count - 1)
    WHERE id = OLD.project_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
CREATE TRIGGER pointstack_project_like_change
  AFTER INSERT OR DELETE ON public.pointstack_project_likes
  FOR EACH ROW EXECUTE FUNCTION public.pointstack_update_project_like_count();
-- Function to update conversation timestamp on new message
CREATE OR REPLACE FUNCTION public.pointstack_update_conversation_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.pointstack_conversations
  SET updated_at = now()
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
CREATE TRIGGER pointstack_message_created
  AFTER INSERT ON public.pointstack_messages
  FOR EACH ROW EXECUTE FUNCTION public.pointstack_update_conversation_timestamp();
-- Function to update user reputation on upvotes received
CREATE OR REPLACE FUNCTION public.pointstack_update_user_reputation()
RETURNS TRIGGER AS $$
DECLARE
  post_author_id UUID;
BEGIN
  -- Get the post author
  SELECT author_id INTO post_author_id FROM public.pointstack_posts WHERE id = COALESCE(NEW.post_id, OLD.post_id);

  IF TG_OP = 'INSERT' THEN
    UPDATE public.profiles
    SET reputation_score = reputation_score + (NEW.vote_type * 10)
    WHERE id = post_author_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.profiles
    SET reputation_score = reputation_score - (OLD.vote_type * 10)
    WHERE id = post_author_id;
  ELSIF TG_OP = 'UPDATE' THEN
    UPDATE public.profiles
    SET reputation_score = reputation_score - (OLD.vote_type * 10) + (NEW.vote_type * 10)
    WHERE id = post_author_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
CREATE TRIGGER pointstack_reputation_change
  AFTER INSERT OR UPDATE OR DELETE ON public.pointstack_post_votes
  FOR EACH ROW EXECUTE FUNCTION public.pointstack_update_user_reputation();
-- ============================================================
-- STORAGE BUCKETS (for images/files)
-- ============================================================

-- Create storage buckets if they don't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('pointstack-images', 'pointstack-images', true)
ON CONFLICT (id) DO NOTHING;
INSERT INTO storage.buckets (id, name, public)
VALUES ('pointstack-files', 'pointstack-files', false)
ON CONFLICT (id) DO NOTHING;
-- Storage policies for pointstack-images (public read, auth write)
CREATE POLICY "Anyone can view pointstack images"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'pointstack-images');
CREATE POLICY "Authenticated users can upload pointstack images"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'pointstack-images' AND auth.role() = 'authenticated');
CREATE POLICY "Users can update their own pointstack images"
  ON storage.objects FOR UPDATE
  USING (bucket_id = 'pointstack-images' AND auth.uid()::text = (storage.foldername(name))[1]);
CREATE POLICY "Users can delete their own pointstack images"
  ON storage.objects FOR DELETE
  USING (bucket_id = 'pointstack-images' AND auth.uid()::text = (storage.foldername(name))[1]);
-- Storage policies for pointstack-files (private)
CREATE POLICY "Users can view their own pointstack files"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'pointstack-files' AND auth.uid()::text = (storage.foldername(name))[1]);
CREATE POLICY "Authenticated users can upload pointstack files"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'pointstack-files' AND auth.role() = 'authenticated');
CREATE POLICY "Users can delete their own pointstack files"
  ON storage.objects FOR DELETE
  USING (bucket_id = 'pointstack-files' AND auth.uid()::text = (storage.foldername(name))[1]);
