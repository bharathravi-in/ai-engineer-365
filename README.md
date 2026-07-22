# AI Engineer 365

AI Engineer 365 is a Learning Management Dashboard for turning a year-long AI/backend upskilling plan into a portfolio project. Instead of keeping the plan in spreadsheets, the repository stores planner content as versioned JSON and renders it through a React + TypeScript dashboard.

## Repository structure

```text
ai-engineer-365/
├── app/                    # React + Vite + TypeScript dashboard
├── planner/                # Month-by-month JSON learning plans
├── docs/                   # Architecture and product documentation
├── notes/                  # Markdown study notes
├── projects/               # Monthly portfolio project specs
├── scripts/                # Automation and data generation scripts
├── excel/                  # Imported/exported spreadsheet assets
└── README.md
```

## Current UI

- Dashboard cards for overall progress, current day, planned hours, and projects.
- Daily planner that reads JSON and shows learning objectives, docs, readings, exercises, mini projects, interview questions, and completion checklist.
- Resource library for official docs, books, practice websites, and cheat sheets.
- Markdown notes editor with live preview.
- Monthly project tracker with PRD, architecture, tech stack, tasks, progress, and GitHub link fields.

## Tech stack

- Frontend: React 19 + TypeScript + Vite
- UI: Material UI
- State: Zustand
- Charts: Recharts
- Markdown: react-markdown
- Storage: JSON now, Supabase later

## Run locally

```bash
npm install
npm run dev
```

> Note: this repository is configured as an npm workspace. Run commands from the repository root unless you intentionally want to work only inside `app/`.

## Build

```bash
npm run build
```

## Validate planner JSON

```bash
npm run check:json
```

## Planner format

Each month lives in `planner/month-XX.json`. Each day follows this shape:

```json
{
  "day": 1,
  "title": "PostgreSQL Installation",
  "duration": "2h",
  "learningObjective": "Install PostgreSQL and connect locally.",
  "videos": [],
  "docs": [],
  "reading": [],
  "practice": [],
  "tasks": [],
  "miniProject": "Create a learning_log table.",
  "interviewQuestions": [],
  "notes": "",
  "completed": false
}
```

## Suggested commit style

- `feat(day-001): add PostgreSQL learning plan`
- `feat(ui): dashboard progress cards`
- `docs(day-001): add study notes`

## Conflict resolution notes

The root `.gitignore`, `package.json`, and `README.md` are the canonical versions for this branch. Keep root scripts delegating into `app/`, keep generated outputs ignored, and keep planner content documented as JSON-first source data.
