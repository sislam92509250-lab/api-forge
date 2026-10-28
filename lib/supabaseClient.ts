import { createBrowserSupabaseClient } from '@supabase/auth-helpers-nextjs';
import { Database } from '@/supabase/types';

export const supabase = createBrowserSupabaseClient<Database>();
