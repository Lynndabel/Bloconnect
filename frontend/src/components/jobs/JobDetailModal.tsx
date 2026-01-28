"use client";

import { Job } from "@/types/job";
import StatusBadge from "@/components/ui/StatusBadge";

type Props = {
  job?: Job | null;
  open: boolean;
  onClose: () => void;
};

function Field({ label, value }: { label: string; value: string }) {
  return (
    <div className="text-sm">
      <div className="text-zinc-500 dark:text-zinc-400">{label}</div>
      <div className="mt-0.5 font-medium">{value}</div>
    </div>
  );
}

export default function JobDetailModal({ job, open, onClose }: Props) {
  if (!open || !job) return null;

  const deadline = (() => {
    try {
      const d = new Date(job.deadline);
      return d.toLocaleString();
    } catch {
      return job.deadline;
    }
  })();

  const titleId = `job-detail-title-${job.id}`;
  return (
    <div
      className="fixed inset-0 z-50 flex items-end justify-center bg-black/40 p-0 sm:items-center sm:p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby={titleId}
      onClick={onClose}
      onKeyDown={(e) => {
        if (e.key === "Escape") {
          e.stopPropagation();
          onClose();
        }
      }}
    >
      <div
        className="max-h-[90vh] w-full rounded-t-2xl bg-white p-5 shadow-xl dark:bg-zinc-900 sm:max-w-lg sm:rounded-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-start justify-between gap-3">
          <div>
            <h3 id={titleId} className="text-lg font-semibold">{job.title}</h3>
            <div className="mt-1 text-sm text-zinc-600 dark:text-zinc-400">
              <span className="font-medium">{job.client.name}</span>
            </div>
          </div>
          <StatusBadge status={job.status} />
        </div>

        <div className="mt-4 grid gap-4 sm:grid-cols-2">
          <Field label="Budget" value={`Ξ ${job.budgetEth}`} />
          <Field label="Deadline" value={deadline} />
        </div>

        <div className="mt-6 flex items-center justify-end gap-2">
          <button
            className="rounded-full border border-black/10 px-4 py-1.5 text-sm transition-colors hover:bg-black/5 dark:border-white/20 dark:hover:bg-white/10"
            onClick={onClose}
          >
            Close
          </button>
          <button
            className="rounded-full bg-black px-4 py-1.5 text-sm text-white transition-colors hover:bg-zinc-800 dark:bg-zinc-50 dark:text-black dark:hover:bg-zinc-300"
            disabled
            title="Submit work (coming soon)"
          >
            Submit Work
          </button>
        </div>
      </div>
    </div>
  );
}
