"use client";

import PillButton from "@/components/ui/PillButton";
import SearchInput from "@/components/ui/SearchInput";
import Switch from "@/components/ui/Switch";
import { JobStatus } from "@/types/job";

export type SortKey = "deadline_asc" | "deadline_desc" | "budget_desc" | "budget_asc";

type Props = {
  tabs: (JobStatus | "all")[];
  activeTab: JobStatus | "all";
  onTab: (t: JobStatus | "all") => void;
  counts?: Partial<Record<JobStatus | "all", number>>;
  query: string;
  onQuery: (v: string) => void;
  sort: SortKey;
  onSort: (s: SortKey) => void;
  compact: boolean;
  onCompact: (v: boolean) => void;
  onExport?: () => void;
};

export default function FiltersBar({ tabs, activeTab, onTab, counts, query, onQuery, sort, onSort, compact, onCompact, onExport }: Props) {
  return (
    <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:gap-3">
      <div className="flex items-center gap-2 text-sm">
        {tabs.map((t) => {
          const label = t.charAt(0).toUpperCase() + t.slice(1);
          const c = counts?.[t];
          return (
            <PillButton key={t} active={activeTab === t} onClick={() => onTab(t)}>
              {label}
              {typeof c === 'number' && (
                <span className="ml-2 inline-flex min-w-5 items-center justify-center rounded-full bg-black/10 px-1 text-[11px] leading-5 dark:bg-white/10">
                  {c}
                </span>
              )}
            </PillButton>
          );
        })}
      </div>
      <div className="flex items-center gap-2">
        <SearchInput placeholder="Search jobs, clients, IDs" value={query} onChange={(e) => onQuery(e.target.value)} />
        <select
          value={sort}
          onChange={(e) => onSort(e.target.value as SortKey)}
          className="rounded-full border border-black/10 bg-transparent px-3 py-2 text-sm dark:border-white/20"
          aria-label="Sort jobs"
        >
          <option value="deadline_asc">Deadline ↑</option>
          <option value="deadline_desc">Deadline ↓</option>
          <option value="budget_desc">Budget ↓</option>
          <option value="budget_asc">Budget ↑</option>
        </select>
        <div className="flex items-center gap-2 rounded-full border border-black/10 px-3 py-1 text-sm dark:border-white/20">
          <span className="text-zinc-600 dark:text-zinc-400">Compact</span>
          <Switch checked={compact} onChange={onCompact} aria-label="Toggle compact view" />
        </div>
        <button
          type="button"
          disabled={!onExport}
          onClick={onExport}
          title={"Export current jobs to CSV"}
          className="rounded-full border border-black/10 px-3 py-2 text-sm text-zinc-600 transition-colors hover:bg-black/5 disabled:opacity-50 dark:border-white/20 dark:text-zinc-300 dark:hover:bg-white/10"
        >
          Export CSV
        </button>
      </div>
    </div>
  );
}
