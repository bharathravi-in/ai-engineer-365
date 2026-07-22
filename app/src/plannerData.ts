import month01 from '../../planner/month-01.json';
import month02 from '../../planner/month-02.json';
import type { PlannerMonth } from './types';

export const plannerMonths = [month01, month02] as PlannerMonth[];
export const plannerDays = plannerMonths.flatMap((month) => month.days);
