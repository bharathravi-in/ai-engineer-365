export type PlannerDay = {
  day: number;
  title: string;
  duration: string;
  learningObjective: string;
  videos: string[];
  docs: string[];
  reading: string[];
  practice: string[];
  tasks: string[];
  miniProject: string;
  interviewQuestions: string[];
  notes: string;
  completed: boolean;
};

export type MonthlyProject = {
  name: string;
  prd: string;
  architecture: string;
  techStack: string[];
  tasks: string[];
  progress: number;
  githubUrl: string;
};

export type PlannerMonth = {
  month: number;
  title: string;
  goal: string;
  project: MonthlyProject;
  days: PlannerDay[];
};
