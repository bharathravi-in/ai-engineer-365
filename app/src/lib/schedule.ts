import type { Module, Topic, Enrollment } from './api';

export type ScheduledItem = { topic: Topic; moduleTitle: string };
export type ScheduleDay = {
  date: Date;
  isWeekend: boolean;
  budgetHours: number;
  usedHours: number;
  items: ScheduledItem[];
};

const isWeekend = (d: Date) => d.getDay() === 0 || d.getDay() === 6;

/**
 * Turn an ordered list of topics into a dated, day-by-day plan based on the
 * learner's availability. Each calendar day is filled up to that day's hour
 * budget (weekday vs weekend). A topic longer than a full day still gets its
 * own day so the plan always advances.
 *
 * ALL topics are scheduled (completed ones stay on their original day, shown as
 * done) so the journey is stable and you can see what you finished on each day.
 */
export function generateSchedule(
  modules: Module[],
  enrollment: Pick<Enrollment, 'start_date' | 'weekday_hours' | 'weekend_hours'>,
): ScheduleDay[] {
  const items: ScheduledItem[] = [];
  for (const m of modules) {
    for (const t of m.topics) {
      items.push({ topic: t, moduleTitle: m.title });
    }
  }
  if (!items.length) return [];

  const weekday = Math.max(0.5, Number(enrollment.weekday_hours) || 2);
  const weekend = Math.max(0, Number(enrollment.weekend_hours) || 0);

  // Parse start_date (YYYY-MM-DD) as a local date.
  const [y, mo, d] = (enrollment.start_date || new Date().toISOString().slice(0, 10))
    .split('-')
    .map(Number);
  let cursor = new Date(y, (mo || 1) - 1, d || 1);

  const days: ScheduleDay[] = [];
  let idx = 0;
  let guard = 0;
  while (idx < items.length && guard < 5000) {
    guard += 1;
    const wknd = isWeekend(cursor);
    const budget = wknd ? weekend : weekday;
    // A 0-hour day (e.g. weekend_hours = 0) is a rest day — skip it.
    if (budget <= 0) {
      cursor = new Date(cursor.getFullYear(), cursor.getMonth(), cursor.getDate() + 1);
      continue;
    }
    const day: ScheduleDay = { date: new Date(cursor), isWeekend: wknd, budgetHours: budget, usedHours: 0, items: [] };
    while (idx < items.length) {
      const next = items[idx];
      const h = Number(next.topic.est_hours) || 1;
      // Always take at least one topic; otherwise stop when the day is full.
      if (day.items.length > 0 && day.usedHours + h > budget) break;
      day.items.push(next);
      day.usedHours += h;
      idx += 1;
    }
    days.push(day);
    cursor = new Date(cursor.getFullYear(), cursor.getMonth(), cursor.getDate() + 1);
  }
  return days;
}
