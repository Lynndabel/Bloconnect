"use client";

import { useEffect, useMemo, useState } from "react";
import { mockJobs } from "@/data/mockJobs";
import { JobStatus } from "@/types/job";
import PillButton from "@/components/ui/PillButton";
import JobRow from "@/components/jobs/JobRow";
import JobDetailModal from "@/components/jobs/JobDetailModal";
import { Job } from "@/types/job";
import Skeleton from "@/components/ui/Skeleton";
import EmptyState from "@/components/ui/EmptyState";
import FiltersBar, { SortKey } from "@/components/jobs/FiltersBar";
import Pagination from "@/components/ui/Pagination";
import useLocalStorage from "@/hooks/useLocalStorage";

const TABS: (JobStatus | "all")[] = ["all", "active", "pending", "completed", "disputed"];

export default function JobsList() {
  const [tab, setTab] = useLocalStorage<(typeof TABS)[number]>("jobs-tab", "all");
  const [selected, setSelected] = useState<Job | null>(null);
  const [query, setQuery] = useLocalStorage<string>("jobs-query", "");
  const [sort, setSort] = useLocalStorage<SortKey>("jobs-sort", "deadline_asc");

  const jobs = useMemo(() => {
    let data = tab === "all" ? mockJobs : mockJobs.filter((j) => j.status === tab);
    if (query.trim()) {
      const q = query.toLowerCase();
      data = data.filter((j) => j.title.toLowerCase().includes(q) || j.client.name.toLowerCase().includes(q) || j.id.toLowerCase().includes(q));
    }
    const arr = [...data];
    if (sort === "deadline_asc") arr.sort((a, b) => +new Date(a.deadline) - +new Date(b.deadline));
    if (sort === "deadline_desc") arr.sort((a, b) => +new Date(b.deadline) - +new Date(a.deadline));
    if (sort === "budget_desc") arr.sort((a, b) => b.budgetEth - a.budgetEth);
    if (sort === "budget_asc") arr.sort((a, b) => a.budgetEth - b.budgetEth);
    return arr;
  }, [tab, query, sort]);

  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const pageSize = 5;
  const totalPages = Math.max(1, Math.ceil(jobs.length / pageSize));
  const pageJobs = useMemo(() => {
    const start = (page - 1) * pageSize;
    return jobs.slice(start, start + pageSize);
  }, [jobs, page]);
  useEffect(() => {
    const t = setTimeout(() => setLoading(false), 500);
    return () => clearTimeout(t);
  }, [tab, query, sort]);
  useEffect(() => {
    // reset page when filters change
    setPage(1);
  }, [tab, query, sort]);
  const [compact, setCompact] = useLocalStorage<boolean>("jobs-compact", false);

  const counts = useMemo(() => {
    const all = mockJobs.length;
    const by: Record<(typeof TABS)[number], number> = {
      all,
      active: mockJobs.filter((j) => j.status === "active").length,
      pending: mockJobs.filter((j) => j.status === "pending").length,
      completed: mockJobs.filter((j) => j.status === "completed").length,
      disputed: mockJobs.filter((j) => j.status === "disputed").length,
    } as any;
    return by;
  }, []);

  function handleExport() {
    const headers = ["id", "title", "client", "budgetEth", "deadline", "status"];
    const rows = jobs.map((j) => [j.id, j.title, j.client.name, j.budgetEth, j.deadline, j.status]);
    const csv = [headers.join(","), ...rows.map((r) => r.map((v) => `"${String(v).replace(/"/g, '""')}"`).join(","))].join("\n");
    const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `jobs_${tab}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  }

  return (
    <section className="mt-10">
      <div className="mb-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <h2 className="text-lg font-medium">Jobs</h2>
        <FiltersBar
          tabs={TABS}
          activeTab={tab}
          onTab={setTab}
          counts={counts}
          query={query}
          onQuery={setQuery}
          sort={sort}
          onSort={setSort}
          compact={compact}
          onCompact={setCompact}
          onExport={handleExport}
        />
      </div>

      <div className="grid gap-3">
        {loading ? (
          Array.from({ length: 3 }).map((_, i) => (
            <div key={i} className="rounded-2xl border border-black/10 p-4 dark:border-white/15">
              <Skeleton className="h-4 w-40" />
              <div className="mt-2 flex items-center gap-2">
                <Skeleton className="h-6 w-6 rounded-full" />
                <Skeleton className="h-4 w-24" />
                <Skeleton className="h-4 w-20" />
                <Skeleton className="h-4 w-28" />
              </div>
            </div>
          ))
        ) : jobs.length === 0 ? (
          <EmptyState title="No jobs in this view" description="Try switching tabs or adjust your search filters." />
        ) : (
          pageJobs.map((job) => <JobRow key={job.id} job={job} onClick={setSelected} compact={compact} />)
        )}
      </div>

      {!loading && jobs.length > 0 && (
        <Pagination
          page={page}
          totalPages={totalPages}
          label={`Showing ${(page - 1) * pageSize + 1}–${Math.min(page * pageSize, jobs.length)} of ${jobs.length}`}
          onPrev={() => setPage((p) => Math.max(1, p - 1))}
          onNext={() => setPage((p) => Math.min(totalPages, p + 1))}
        />
      )}

      <JobDetailModal job={selected ?? undefined} open={!!selected} onClose={() => setSelected(null)} />
    </section>
  );
}
