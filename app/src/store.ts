import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import type { Session, User } from '@supabase/supabase-js';
import { supabase, isSupabaseConfigured } from './lib/supabase';
import * as api from './lib/api';
import { useTrackStore } from './trackStore';

/**
 * App-wide session + theme store. All study-plan data lives in useTrackStore;
 * this store only owns authentication (via Supabase) and the light/dark theme.
 */
type ThemeMode = 'light' | 'dark';
type Profile = { id: string; email: string | null; is_admin: boolean };

type AppState = {
  themeMode: ThemeMode;
  toggleTheme: () => void;

  supabaseEnabled: boolean;
  session: Session | null;
  user: User | null;
  profile: Profile | null;
  authReady: boolean;

  initApp: () => Promise<void>;
  signIn: (email: string, password: string) => Promise<{ error: string | null }>;
  signUp: (email: string, password: string) => Promise<{ error: string | null }>;
  signOut: () => Promise<void>;
};

async function fetchProfile(): Promise<Profile | null> {
  if (!supabase) return null;
  try {
    return await api.getMe();
  } catch {
    return null;
  }
}

export const useDashboardStore = create<AppState>()(
  persist(
    (set, get) => ({
      themeMode: 'light',
      toggleTheme: () => set((s) => ({ themeMode: s.themeMode === 'light' ? 'dark' : 'light' })),

      supabaseEnabled: isSupabaseConfigured,
      session: null,
      user: null,
      profile: null,
      authReady: !isSupabaseConfigured,

      initApp: async () => {
        if (!supabase) {
          set({ authReady: true });
          return;
        }
        const { data } = await supabase.auth.getSession();
        set({ session: data.session ?? null, user: data.session?.user ?? null });
        if (data.session?.user) set({ profile: await fetchProfile() });
        set({ authReady: true });

        supabase.auth.onAuthStateChange(async (_event, session) => {
          set({ session: session ?? null, user: session?.user ?? null });
          if (session?.user) {
            set({ profile: await fetchProfile() });
          } else {
            set({ profile: null });
            useTrackStore.getState().reset();
          }
        });
      },

      signIn: async (email, password) => {
        if (!supabase) return { error: 'Supabase is not configured.' };
        const { error } = await supabase.auth.signInWithPassword({ email, password });
        return { error: error?.message ?? null };
      },
      signUp: async (email, password) => {
        if (!supabase) return { error: 'Supabase is not configured.' };
        const { error } = await supabase.auth.signUp({ email, password });
        return { error: error?.message ?? null };
      },
      signOut: async () => {
        if (!supabase) return;
        await supabase.auth.signOut();
        useTrackStore.getState().reset();
      },
    }),
    {
      name: 'skillmap-store',
      version: 1,
      storage: createJSONStorage(() => localStorage),
      partialize: (s) => ({ themeMode: s.themeMode }),
    },
  ),
);

export const useIsAdmin = () => useDashboardStore((s) => Boolean(s.profile?.is_admin));
