import type { PlannerMonth } from './types';

/** Split a textarea value into a trimmed, non-empty list (one item per line). */
export function linesToList(value: string): string[] {
  return value
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean);
}

export function listToLines(list: string[]): string {
  return list.join('\n');
}

/** Two-digit, repo-style file name for a month, e.g. month-03.json. */
export function monthFileName(month: number): string {
  return `month-${String(month).padStart(2, '0')}.json`;
}

function download(fileName: string, contents: string) {
  const blob = new Blob([contents], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement('a');
  anchor.href = url;
  anchor.download = fileName;
  document.body.appendChild(anchor);
  anchor.click();
  anchor.remove();
  URL.revokeObjectURL(url);
}

/** Download a single month as the JSON file you commit under /planner. */
export function downloadMonth(month: PlannerMonth) {
  download(monthFileName(month.month), `${JSON.stringify(month, null, 2)}\n`);
}

/** Parse an uploaded month JSON file, throwing a readable error on bad shape. */
export function parseMonthFile(text: string): PlannerMonth {
  const data = JSON.parse(text);
  if (typeof data.month !== 'number' || !Array.isArray(data.days)) {
    throw new Error('File is not a valid month planner (expected "month" number and "days" array).');
  }
  return data as PlannerMonth;
}
