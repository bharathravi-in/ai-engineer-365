import { create } from 'zustand';
import { plannerDays, plannerMonths } from './plannerData';
export { plannerDays, plannerMonths } from './plannerData';

type DashboardState = {
  completedDays: Set<number>;
  notesByDay: Record<number, string>;
  selectedDay: number;
  toggleDay: (day: number) => void;
  setSelectedDay: (day: number) => void;
  saveNote: (day: number, note: string) => void;
};

const initialCompleted = plannerDays.filter((day) => day.completed).map((day) => day.day);

export const useDashboardStore = create<DashboardState>((set) => ({
  completedDays: new Set(initialCompleted),
  notesByDay: Object.fromEntries(plannerDays.map((day) => [day.day, day.notes])),
  selectedDay: plannerDays[0]?.day ?? 1,
  toggleDay: (day) => set((state) => {
    const completedDays = new Set(state.completedDays);
    completedDays.has(day) ? completedDays.delete(day) : completedDays.add(day);
    return { completedDays };
  }),
  setSelectedDay: (selectedDay) => set({ selectedDay }),
  saveNote: (day, note) => set((state) => ({ notesByDay: { ...state.notesByDay, [day]: note } })),
}));

export const dashboardStats = {
  totalDays: plannerDays.length,
  totalHours: plannerDays.reduce((total, day) => total + Number.parseFloat(day.duration), 0),
  totalProjects: plannerMonths.length,
};
