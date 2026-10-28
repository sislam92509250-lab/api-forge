-- 2024-10-28 Initial schema for APIForge
-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. profiles (one-to-one with auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_uid uuid NOT NULL UNIQUE,
    full_name text,
    avatar_url text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

-- 2. workspaces
CREATE TABLE IF NOT EXISTS public.workspaces (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    owner_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

-- 3. workspace_members
CREATE TYPE public.workspace_role AS ENUM ('owner','admin','editor','viewer');
CREATE TABLE IF NOT EXISTS public.workspace_members (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id uuid NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
    profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role public.workspace_role NOT NULL DEFAULT 'viewer',
    invited_at timestamp with time zone DEFAULT now(),
    UNIQUE (workspace_id, profile_id)
);

-- 4. collections
CREATE TABLE IF NOT EXISTS public.collections (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id uuid NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
    name text NOT NULL,
    parent_id uuid REFERENCES public.collections(id) ON DELETE CASCADE,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

-- 5. api_requests
CREATE TABLE IF NOT EXISTS public.api_requests (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    collection_id uuid NOT NULL REFERENCES public.collections(id) ON DELETE CASCADE,
    name text NOT NULL,
    method text NOT NULL CHECK (method IN ('GET','POST','PUT','PATCH','DELETE','HEAD','OPTIONS')),
    url text NOT NULL,
    body jsonb,
    auth jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

-- 6. request_headers
CREATE TABLE IF NOT EXISTS public.request_headers (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id uuid NOT NULL REFERENCES public.api_requests(id) ON DELETE CASCADE,
    "key" text NOT NULL,
    "value" text NOT NULL,
    UNIQUE (request_id, "key")
);

-- 7. request_parameters (query params)
CREATE TABLE IF NOT EXISTS public.request_parameters (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id uuid NOT NULL REFERENCES public.api_requests(id) ON DELETE CASCADE,
    "key" text NOT NULL,
    "value" text NOT NULL,
    UNIQUE (request_id, "key")
);

-- 8. environments
CREATE TABLE IF NOT EXISTS public.environments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id uuid NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
    name text NOT NULL,
    is_production boolean NOT NULL DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

-- 9. environment_variables
CREATE TABLE IF NOT EXISTS public.environment_variables (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    environment_id uuid NOT NULL REFERENCES public.environments(id) ON DELETE CASCADE,
    "key" text NOT NULL,
    "value" text NOT NULL,
    is_secret boolean NOT NULL DEFAULT false,
    UNIQUE (environment_id, "key")
);

-- 10. test_suites
CREATE TABLE IF NOT EXISTS public.test_suites (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id uuid NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
    name text NOT NULL,
    description text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

-- 11. test_assertions
CREATE TYPE public.assertion_type AS ENUM ('status_code','header','json_path','response_time','schema');
CREATE TABLE IF NOT EXISTS public.test_assertions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    suite_id uuid NOT NULL REFERENCES public.test_suites(id) ON DELETE CASCADE,
    request_id uuid NOT NULL REFERENCES public.api_requests(id) ON DELETE CASCADE,
    assertion_type public.assertion_type NOT NULL,
    expected jsonb NOT NULL,
    "path" text, -- for json_path assertions
    created_at timestamp with time zone DEFAULT now()
);

-- 12. test_executions
CREATE TABLE IF NOT EXISTS public.test_executions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    suite_id uuid NOT NULL REFERENCES public.test_suites(id) ON DELETE CASCADE,
    workspace_id uuid NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
    initiated_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE SET NULL,
    status text NOT NULL CHECK (status IN ('pending','running','completed','failed')),
    started_at timestamp with time zone DEFAULT now(),
    finished_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now()
);

-- 13. test_results
CREATE TABLE IF NOT EXISTS public.test_results (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    execution_id uuid NOT NULL REFERENCES public.test_executions(id) ON DELETE CASCADE,
    assertion_id uuid NOT NULL REFERENCES public.test_assertions(id) ON DELETE CASCADE,
    passed boolean NOT NULL,
    actual jsonb,
    error_message text,
    created_at timestamp with time zone DEFAULT now()
);

-- 14. request_history
CREATE TABLE IF NOT EXISTS public.request_history (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id uuid NOT NULL REFERENCES public.api_requests(id) ON DELETE CASCADE,
    profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    workspace_id uuid NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
    method text NOT NULL,
    url text NOT NULL,
    status integer,
    duration_ms integer,
    executed_at timestamp with time zone DEFAULT now()
);

-- 15. audit_logs
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    action text NOT NULL,
    details jsonb,
    occurred_at timestamp with time zone DEFAULT now()
);

-- Triggers for timestamps
CREATE OR REPLACE FUNCTION public.update_timestamp()
RETURNS trigger AS $$
BEGIN
   NEW.updated_at = now();
   RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to tables with updated_at column
DO $$
DECLARE r record;
BEGIN
   FOR r IN SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename IN (
       'profiles','workspaces','collections','api_requests','environments','test_suites','test_executions','audit_logs'
   )
   LOOP
       EXECUTE format('CREATE TRIGGER %I_update_timestamp BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();', r.tablename, r.tablename);
   END LOOP;
END $$;

-- Row Level Security (RLS) policies
-- Enable RLS on tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workspaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workspace_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.api_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.request_headers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.request_parameters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.environments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.environment_variables ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.test_suites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.test_assertions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.test_executions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.test_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.request_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Example policies (simplified) – actual policies will be more granular
-- profiles: only owner can select/update own row
CREATE POLICY "self_select" ON public.profiles FOR SELECT USING (auth.uid() = auth_uid);
CREATE POLICY "self_update" ON public.profiles FOR UPDATE USING (auth.uid() = auth_uid);

-- workspaces: users in workspace can select, only owners can delete
CREATE POLICY "workspace_select" ON public.workspaces FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.workspace_members wm WHERE wm.workspace_id = workspaces.id AND wm.profile_id = (SELECT id FROM public.profiles WHERE auth_uid = auth.uid()))
);
CREATE POLICY "workspace_insert" ON public.workspaces FOR INSERT WITH CHECK (
    auth.uid() = auth_uid
);

-- workspace_members: owners can manage members, members can view themselves
CREATE POLICY "members_select" ON public.workspace_members FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.workspace_members wm WHERE wm.workspace_id = workspace_members.workspace_id AND wm.profile_id = (SELECT id FROM public.profiles WHERE auth_uid = auth.uid()))
);
CREATE POLICY "members_insert" ON public.workspace_members FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.workspace_members wm WHERE wm.workspace_id = workspace_id AND wm.profile_id = (SELECT id FROM public.profiles WHERE auth_uid = auth.uid()) AND wm.role = 'owner')
);

-- Other tables: similar pattern – allow rows only if user belongs to workspace
-- For brevity, policies are omitted here; they should follow the same principle.

