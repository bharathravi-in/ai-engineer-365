import { create } from 'zustand';
import * as api from './lib/api';
import type { Enrollment, TrackDetail, TrackSummary } from './lib/api';

/**
 * Store for the multi-track roadmap experience (catalog, enrollment, per-topic
 * progress/notes). Auth lives in useDashboardStore; this store just calls the
 * Node API (which attaches the Supabase JWT). Progress/notes are only loaded
 * and persisted for signed-in users — guests can browse but not track.
 */
type TrackState = {
  catalog: TrackSummary[];
  catalogLoading: boolean;
  current: TrackDetail | null;
  currentLoading: boolean;
  enrollments: Record<string, Enrollment>; // keyed by track_id
  completed: Set<string>; // topic ids
  notes: Record<string, string>; // topic_id -> content
  error: string | null;

  loadCatalog: () => Promise<void>;
  loadTrack: (slug: string) => Promise<void>;
  loadEnrollments: () => Promise<void>;
  loadTrackState: (trackId: string) => Promise<void>;
  enroll: (body: Enrollment) => Promise<{ error: string | null }>;
  leave: (trackId: string) => Promise<void>;
  toggleTopic: (topicId: string) => void;
  saveTopicNote: (topicId: string, content: string) => void;
  reset: () => void;
};

export const useTrackStore = create<TrackState>((set, get) => ({
  catalog: [],
  catalogLoading: false,
  current: null,
  currentLoading: false,
  enrollments: {},
  completed: new Set(),
  notes: {},
  error: null,

  loadCatalog: async () => {
    set({ catalogLoading: true, error: null });
    try {
      const { tracks } = await api.getTracks();
      set({ catalog: tracks, catalogLoading: false });
    } catch (e) {
      set({ catalogLoading: false, error: e instanceof Error ? e.message : 'Failed to load tracks.' });
    }
  },

  loadTrack: async (slug) => {
    set({ currentLoading: true, error: null });
    try {
      const detail = await api.getTrack(slug);
      set({ current: detail, currentLoading: false });
    } catch (e) {
      set({ current: null, currentLoading: false, error: e instanceof Error ? e.message : 'Track not found.' });
    }
  },

  loadEnrollments: async () => {
    try {
      const { enrollments } = await api.getMyEnrollments();
      set({ enrollments: Object.fromEntries(enrollments.map((e) => [e.track_id, e])) });
    } catch {
      set({ enrollments: {} });
    }
  },

  loadTrackState: async (trackId) => {
    try {
      const { progress, notes } = await api.getTrackState(trackId);
      set({
        completed: new Set(progress.filter((p) => p.completed).map((p) => p.topic_id)),
        notes: Object.fromEntries(notes.map((n) => [n.topic_id, n.content ?? ''])),
      });
    } catch {
      /* keep existing */
    }
  },

  enroll: async (body) => {
    try {
      await api.enrollInTrack(body);
      await get().loadEnrollments();
      return { error: null };
    } catch (e) {
      return { error: e instanceof Error ? e.message : 'Failed to enroll.' };
    }
  },

  leave: async (trackId) => {
    await api.leaveTrack(trackId).catch(() => {});
    await get().loadEnrollments();
  },

  toggleTopic: (topicId) => {
    const completed = new Set(get().completed);
    const nowDone = !completed.has(topicId);
    if (nowDone) completed.add(topicId);
    else completed.delete(topicId);
    set({ completed });
    void api.putTopicProgress(topicId, nowDone).catch(() => {});
  },

  saveTopicNote: (topicId, content) => {
    set({ notes: { ...get().notes, [topicId]: content } });
    void api.putTopicNote(topicId, content).catch(() => {});
  },

  reset: () => set({ enrollments: {}, completed: new Set(), notes: {} }),
}));
