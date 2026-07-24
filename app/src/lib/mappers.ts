import type { MonthlyProject, PlannerDay, PlannerMonth } from '../types';

export type PlanStatus = 'draft' | 'published';

export type MonthRow = {
  id: string;
  month_number: number;
  title: string;
  goal: string | null;
  project: MonthlyProject | null;
  status: PlanStatus;
};

export type DayRow = {
  id: string;
  month_id: string;
  day_number: number;
  title: string;
  duration: string | null;
  learning_objective: string | null;
  videos: string[] | null;
  docs: string[] | null;
  reading: string[] | null;
  practice: string[] | null;
  tasks: string[] | null;
  mini_project: string | null;
  interview_questions: string[] | null;
  status: PlanStatus;
};

const emptyProject: MonthlyProject = {
  name: '',
  prd: '',
  architecture: '',
  techStack: [],
  tasks: [],
  progress: 0,
  githubUrl: '',
};

export function dayRowToModel(row: DayRow): PlannerDay {
  return {
    day: row.day_number,
    title: row.title,
    duration: row.duration ?? '2h',
    learningObjective: row.learning_objective ?? '',
    videos: row.videos ?? [],
    docs: row.docs ?? [],
    reading: row.reading ?? [],
    practice: row.practice ?? [],
    tasks: row.tasks ?? [],
    miniProject: row.mini_project ?? '',
    interviewQuestions: row.interview_questions ?? [],
    notes: '',
    completed: false,
  };
}

export function assembleMonths(monthRows: MonthRow[], dayRows: DayRow[]): PlannerMonth[] {
  const daysByMonthId = new Map<string, DayRow[]>();
  for (const day of dayRows) {
    const list = daysByMonthId.get(day.month_id) ?? [];
    list.push(day);
    daysByMonthId.set(day.month_id, list);
  }
  return monthRows
    .slice()
    .sort((a, b) => a.month_number - b.month_number)
    .map((month) => ({
      month: month.month_number,
      title: month.title,
      goal: month.goal ?? '',
      project: month.project ?? { ...emptyProject },
      days: (daysByMonthId.get(month.id) ?? [])
        .slice()
        .sort((a, b) => a.day_number - b.day_number)
        .map(dayRowToModel),
    }));
}

/** Model -> DB columns for inserts/updates (day_number and month_id set by caller). */
export function dayModelToRow(day: PlannerDay): Omit<DayRow, 'id' | 'month_id' | 'status'> {
  return {
    day_number: day.day,
    title: day.title,
    duration: day.duration,
    learning_objective: day.learningObjective,
    videos: day.videos,
    docs: day.docs,
    reading: day.reading,
    practice: day.practice,
    tasks: day.tasks,
    mini_project: day.miniProject,
    interview_questions: day.interviewQuestions,
  };
}
