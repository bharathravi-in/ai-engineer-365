import month01 from '../../planner/month-01.json';
import month02 from '../../planner/month-02.json';
import month03 from '../../planner/month-03.json';
import month04 from '../../planner/month-04.json';
import month05 from '../../planner/month-05.json';
import month06 from '../../planner/month-06.json';
import month07 from '../../planner/month-07.json';
import month08 from '../../planner/month-08.json';
import month09 from '../../planner/month-09.json';
import month10 from '../../planner/month-10.json';
import month11 from '../../planner/month-11.json';
import month12 from '../../planner/month-12.json';
import type { PlannerMonth } from './types';

export const plannerMonths = [
  month01,
  month02,
  month03,
  month04,
  month05,
  month06,
  month07,
  month08,
  month09,
  month10,
  month11,
  month12,
] as PlannerMonth[];

export const plannerDays = plannerMonths.flatMap((month) => month.days);
