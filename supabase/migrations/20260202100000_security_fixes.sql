-- Security Fixes Migration
-- ============================================================
-- 1. Prevent users from self-elevating to admin
-- 2. Fix notification INSERT policy
-- ============================================================

-- ============================================================
-- PROTECT is_admin FIELD
-- ============================================================

-- Create a function to prevent users from changing their own is_admin status
CREATE OR REPLACE FUNCTION prevent_self_admin_elevation()
RETURNS TRIGGER AS $$
BEGIN
  -- If the is_admin field is being changed
  IF OLD.is_admin IS DISTINCT FROM NEW.is_admin THEN
    -- Check if the user is trying to modify their own record
    IF auth.uid() = NEW.id THEN
      -- Prevent the change by keeping the old value
      NEW.is_admin := OLD.is_admin;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Create trigger to enforce this on profile updates
DROP TRIGGER IF EXISTS prevent_self_admin_elevation_trigger ON public.profiles;
CREATE TRIGGER prevent_self_admin_elevation_trigger
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION prevent_self_admin_elevation();
-- ============================================================
-- FIX NOTIFICATION INSERT POLICY
-- ============================================================

-- Drop the overly permissive policy if it exists
DROP POLICY IF EXISTS "System can create notifications" ON public.pointstack_notifications;
-- Create a more restrictive policy - only allow creating notifications for yourself
-- or via service role (for system notifications)
CREATE POLICY "Users can create notifications for others"
  ON public.pointstack_notifications FOR INSERT
  WITH CHECK (
    -- Allow service role to create any notification
    auth.jwt()->>'role' = 'service_role'
    -- Or allow authenticated users to create notifications where they are the actor
    OR (auth.uid() IS NOT NULL AND actor_id = auth.uid())
  );
-- ============================================================
-- ADD INDEX FOR FASTER OWNERSHIP LOOKUPS
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_pointstack_posts_author ON public.pointstack_posts (author_id);
CREATE INDEX IF NOT EXISTS idx_pointstack_comments_author ON public.pointstack_post_comments (author_id);
