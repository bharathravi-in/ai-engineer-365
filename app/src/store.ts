import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import type { Session, User } from '@supabase/supabase-js';
import { plannerMonths as baseMonths } from './plannerData';
import type { PlannerDay, PlannerMonth } from './types';
import { supabase, isSupabaseConfigured } from './lib/supabase';
import {
  assembleMonths,
  dayModelToRow,
  type DayRow,
  type MonthRow,
  type PlanStatus,
} from './lib/mappers';
import * as api from './lib/api';

export { plannerMonths, plannerDays } from './plannerData';

export const emptyProject = (): PlannerMonth['project'] => ({
  name: '',
  prd: '',
  architecture: '',
  techStack: [],
  tasks: [],
  progress: 0,
  githubUrl: '',
});

export const emptyDay = (day: number): PlannerDay => ({
  day,
  title: '',
  duration: '2h',
  learningObjective: '',
  videos: [],
  docs: [],
  reading: [],
  practice: [],
  tasks: [],
  miniProject: '',
  interviewQuestions: [],
  notes: '',
  completed: false,
});

/**
 * Local (offline) plan model: the repository JSON under /planner is the source
 * of truth, with UI-added months/days layered on top. Used when Supabase is not
 * configured. When Supabase IS configured, plans are loaded from the database
 * instead (see loadPlans).
 */
function mergeMonths(
  customMonths: PlannerMonth[],
  customDays: Array<{ month: number; day: PlannerDay }>,
): PlannerMonth[] {
  const byMonth = new Map<number, PlannerMonth>();
  for (const month of baseMonths) {
    byMonth.set(month.month, { ...month, days: [...month.days] });
  }
  for (const month of customMonths) {
    if (!byMonth.has(month.month)) {
      byMonth.set(month.month, { ...month, days: [...month.days] });
    }
  }
  for (const { month, day } of customDays) {
    let target = byMonth.get(month);
    if (!target) {
      target = { month, title: `Month ${month}`, goal: '', project: emptyProject(), days: [] };
      byMonth.set(month, target);
    }
    target.days = [...target.days.filter((d) => d.day !== day.day), day];
  }
  const merged = [...byMonth.values()].sort((a, b) => a.month - b.month);
  for (const month of merged) {
    month.days = [...month.days].sort((a, b) => a.day - b.day);
  }
  return merged;
}

function deriveDays(months: PlannerMonth[]) {
  return months.flatMap((month) => month.days);
}

type ThemeMode = 'light' | 'dark';
type Profile = { id: string; email: string | null; is_admin: boolean };
type MonthInput = {
  month_number: number;
  title: string;
  goal: string;
  project: PlannerMonth['project'];
  status: PlanStatus;
};

type DashboardState = {
  months: PlannerMonth[];
  days: PlannerDay[];
  customMonths: PlannerMonth[];
  customDays: Array<{ month: number; day: PlannerDay }>;
  completedDays: Set<number>;
  notesByDay: Record<number, string>;
  selectedDay: number;
  themeMode: ThemeMode;

  // Supabase / auth
  supabaseEnabled: boolean;
  session: Session | null;
  user: User | null;
  profile: Profile | null;
  authReady: boolean;
  plansLoading: boolean;
  loadError: string | null;

  // learner actions
  toggleDay: (day: number) => void;
  setSelectedDay: (day: number) => void;
  saveNote: (day: number, note: string) => void;

  // local (offline) editor actions
  addDay: (month: number, day: PlannerDay) => void;
  addMonth: (month: PlannerMonth) => void;
  resetCustomData: () => void;
  toggleTheme: () => void;

  // supabase lifecycle
  initApp: () => Promise<void>;
  loadPlans: () => Promise<void>;
  signIn: (email: string, password: string) => Promise<{ error: string | null }>;
  signUp: (email: string, password: string) => Promise<{ error: string | null }>;
  signOut: () => Promise<void>;

  // admin CRUD (Supabase)
  adminSaveMonth: (input: MonthInput) => Promise<{ error: string | null }>;
  adminSaveDay: (
    monthNumber: number,
    day: PlannerDay,
    status: PlanStatus,
  ) => Promise<{ error: string | null }>;
  adminSetMonthStatus: (monthNumber: number, status: PlanStatus) => Promise<void>;
  adminSetDayStatus: (dayNumber: number, status: PlanStatus) => Promise<void>;
  adminDeleteDay: (dayNumber: number) => Promise<void>;
  adminDeleteMonth: (monthNumber: number) => Promise<void>;
};

// When Supabase is configured the DATABASE is the sole source of truth: the
// store starts empty and is filled exclusively from the Node API (loadPlans /
// loadUserState). The bundled JSON is used only as the offline fallback.
const initialMonths = isSupabaseConfigured ? [] : mergeMonths([], []);
const initialDays = deriveDays(initialMonths);

async function fetchProfile(): Promise<Profile | null> {
  if (!supabase) return null;
  try {
    return await api.getMe();
  } catch {
    return null;
  }
}

export const useDashboardStore = create<DashboardState>()(
  persist(
    (set, get) => ({
      months: initialMonths,
      days: initialDays,
      customMonths: [],
      customDays: [],
      completedDays: new Set(initialDays.filter((day) => day.completed).map((day) => day.day)),
      notesByDay: Object.fromEntries(initialDays.map((day) => [day.day, day.notes])),
      selectedDay: initialDays[0]?.day ?? 1,
      themeMode: 'light',

      supabaseEnabled: isSupabaseConfigured,
      session: null,
      user: null,
      profile: null,
      authReady: !isSupabaseConfigured,
      plansLoading: false,
      loadError: null,

      toggleTheme: () => set((state) => ({ themeMode: state.themeMode === 'light' ? 'dark' : 'light' })),

      toggleDay: (day) => {
        const state = get();
        const completedDays = new Set(state.completedDays);
        const nowComplete = !completedDays.has(day);
        if (nowComplete) completedDays.add(day);
        else completedDays.delete(day);
        set({ completedDays });
        // Persist via the Node API when signed in.
        if (state.user) {
          void api.putProgress(day, nowComplete).catch(() => {});
        }
      },

      setSelectedDay: (selectedDay) => set({ selectedDay }),

      saveNote: (day, note) => {
        set((state) => ({ notesByDay: { ...state.notesByDay, [day]: note } }));
        const { user } = get();
        if (user) {
          void api.putNote(day, note).catch(() => {});
        }
      },

      addDay: (month, day) => {
        const customDays = [
          ...get().customDays.filter((entry) => !(entry.month === month && entry.day.day === day.day)),
          { month, day },
        ];
        const months = mergeMonths(get().customMonths, customDays);
        set({ customDays, months, days: deriveDays(months), selectedDay: day.day });
      },
      addMonth: (month) => {
        const customMonths = [
          ...get().customMonths.filter((entry) => entry.month !== month.month),
          month,
        ];
        const months = mergeMonths(customMonths, get().customDays);
        set({ customMonths, months, days: deriveDays(months) });
      },
      resetCustomData: () => {
        const months = mergeMonths([], []);
        set({
          customMonths: [],
          customDays: [],
          months,
          days: deriveDays(months),
          completedDays: new Set(initialDays.filter((day) => day.completed).map((day) => day.day)),
          notesByDay: Object.fromEntries(initialDays.map((day) => [day.day, day.notes])),
        });
      },

      // -------------------------------------------------------------------
      // Supabase lifecycle
      // -------------------------------------------------------------------
      initApp: async () => {
        if (!supabase) {
          set({ authReady: true });
          return;
        }
        const { data } = await supabase.auth.getSession();
        set({ session: data.session ?? null, user: data.session?.user ?? null });
        if (data.session?.user) {
          const profile = await fetchProfile();
          set({ profile });
          await loadUserState(set);
        }
        await get().loadPlans();
        set({ authReady: true });

        supabase.auth.onAuthStateChange(async (_event, session) => {
          set({ session: session ?? null, user: session?.user ?? null });
          if (session?.user) {
            const profile = await fetchProfile();
            set({ profile });
            await loadUserState(set);
          } else {
            set({ profile: null });
          }
          await get().loadPlans();
        });
      },

      loadPlans: async () => {
        if (!supabase) return;
        set({ plansLoading: true, loadError: null });
        try {
          const { months: monthRows, days: dayRows } = await api.getPlans();
          const months = assembleMonths(monthRows as MonthRow[], dayRows as DayRow[]);
          const days = deriveDays(months);
          const stillValid = days.some((d) => d.day === get().selectedDay);
          set({
            months,
            days,
            plansLoading: false,
            selectedDay: stillValid ? get().selectedDay : days[0]?.day ?? 1,
          });
        } catch (err) {
          set({ plansLoading: false, loadError: err instanceof Error ? err.message : 'Failed to load plans.' });
        }
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
        set({ completedDays: new Set(), notesByDay: {} });
      },

      // -------------------------------------------------------------------
      // Admin CRUD
      // -------------------------------------------------------------------
      adminSaveMonth: async (input) => {
        if (!supabase) return { error: 'Supabase is not configured.' };
        try {
          await api.adminSaveMonth({
            month_number: input.month_number,
            title: input.title,
            goal: input.goal,
            project: input.project,
            status: input.status,
          });
          await get().loadPlans();
          return { error: null };
        } catch (err) {
          return { error: err instanceof Error ? err.message : 'Failed to save month.' };
        }
      },

      adminSaveDay: async (monthNumber, day, status) => {
        if (!supabase) return { error: 'Supabase is not configured.' };
        try {
          await api.adminSaveDay(monthNumber, dayModelToRow(day), status);
          await get().loadPlans();
          return { error: null };
        } catch (err) {
          return { error: err instanceof Error ? err.message : 'Failed to save day.' };
        }
      },

      adminSetMonthStatus: async (monthNumber, status) => {
        if (!supabase) return;
        await api.adminSetMonthStatus(monthNumber, status).catch(() => {});
        await get().loadPlans();
      },
      adminSetDayStatus: async (dayNumber, status) => {
        if (!supabase) return;
        await api.adminSetDayStatus(dayNumber, status).catch(() => {});
        await get().loadPlans();
      },
      adminDeleteDay: async (dayNumber) => {
        if (!supabase) return;
        await api.adminDeleteDay(dayNumber).catch(() => {});
        await get().loadPlans();
      },
      adminDeleteMonth: async (monthNumber) => {
        if (!supabase) return;
        await api.adminDeleteMonth(monthNumber).catch(() => {});
        await get().loadPlans();
      },
    }),
    {
      name: 'ai-engineer-365-store',
      version: 3,
      storage: createJSONStorage(() => localStorage, {
        replacer: (_key, value) =>
          value instanceof Set ? { __type: 'Set', values: [...value] } : value,
        reviver: (_key, value) => {
          if (value && typeof value === 'object' && (value as { __type?: string }).__type === 'Set') {
            return new Set((value as { values: number[] }).values);
          }
          return value;
        },
      }),
      // When Supabase is configured, persist ONLY UI preferences — never plan
      // content or learner progress. Those come solely from the database via the
      // Node API, so nothing in localStorage can shadow them. In offline mode we
      // still persist the full local/offline state.
      partialize: (state) =>
        isSupabaseConfigured
          ? { selectedDay: state.selectedDay, themeMode: state.themeMode }
          : {
              customMonths: state.customMonths,
              customDays: state.customDays,
              completedDays: state.completedDays,
              notesByDay: state.notesByDay,
              selectedDay: state.selectedDay,
              themeMode: state.themeMode,
            },
      onRehydrateStorage: () => (state) => {
        if (!state) return;
        if (isSupabaseConfigured) {
          // Database is the only source of truth. Drop any plan/progress that a
          // previous (offline) session may have left in localStorage; initApp()
          // fills months/days and completion/notes from the API.
          state.months = [];
          state.days = [];
          state.completedDays = new Set();
          state.notesByDay = {};
          state.customMonths = [];
          state.customDays = [];
          return;
        }
        // Offline mode: rebuild plans from JSON + custom data.
        const months = mergeMonths(state.customMonths, state.customDays);
        state.months = months;
        state.days = deriveDays(months);
      },
    },
  ),
);

/** Load the signed-in user's completion + notes from the Node API into the store. */
async function loadUserState(set: (partial: Partial<DashboardState>) => void) {
  if (!supabase) return;
  try {
    const { progress, notes } = await api.getMyState();
    const completedDays = new Set<number>(progress.filter((r) => r.completed).map((r) => r.day_number));
    const notesByDay: Record<number, string> = {};
    for (const row of notes) notesByDay[row.day_number] = row.content ?? '';
    set({ completedDays, notesByDay });
  } catch {
    /* leave existing (offline/local) state in place on failure */
  }
}

/** Progress + metadata for every month, derived from days and completion state. */
export const useMonthlyProgress = () => {
  const months = useDashboardStore((state) => state.months);
  const completedDays = useDashboardStore((state) => state.completedDays);
  return months.map((month) => {
    const total = month.days.length;
    const done = month.days.filter((day) => completedDays.has(day.day)).length;
    return {
      month: month.month,
      title: month.title,
      goal: month.goal,
      project: month.project,
      totalDays: total,
      completedDays: done,
      percent: total ? Math.round((done / total) * 100) : 0,
      firstDay: month.days[0]?.day,
      hours: month.days.reduce((sum, day) => sum + (Number.parseFloat(day.duration) || 0), 0),
    };
  });
};

export const useDashboardStats = () => {
  const days = useDashboardStore((state) => state.days);
  const months = useDashboardStore((state) => state.months);
  return {
    totalDays: days.length,
    totalHours: days.reduce((total, day) => total + (Number.parseFloat(day.duration) || 0), 0),
    totalProjects: months.length,
  };
};

export const useIsAdmin = () => useDashboardStore((state) => Boolean(state.profile?.is_admin));
