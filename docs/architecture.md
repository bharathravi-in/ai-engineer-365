# Architecture

## Phase 1

The dashboard imports planner JSON files directly and uses Zustand for local UI state. This keeps content versioned and easy to edit while the product shape stabilizes.

## Phase 2

Add search, monthly calendar views, richer resource tagging, and local persistence for completion state and notes.

## Phase 3

Integrate GitHub API metrics for commit activity, add richer charts, and track study streaks from persisted completion timestamps.

## Phase 4

Move storage to Supabase, add authentication, AI mentor chat, and quiz generation.
