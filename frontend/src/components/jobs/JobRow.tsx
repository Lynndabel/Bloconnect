import StatusBadge from "@/components/ui/StatusBadge";
import { Job } from "@/types/job";
import Avatar from "@/components/ui/Avatar";
import { formatDate, formatEth } from "@/utils/formatters";
import IconButton from "@/components/ui/IconButton";

type Props = {
  job: Job;
  onClick?: (job: Job) => void;
  compact?: boolean;
};

// using shared utils for formatting

export default function JobRow({ job, onClick, compact = false }: Props) {
  return (
    <div
      className={`flex flex-col ${compact ? "gap-2 p-3" : "gap-3 p-4"} rounded-2xl border border-black/10 sm:flex-row sm:items-center sm:justify-between dark:border-white/15 ${onClick ? "cursor-pointer hover:bg-black/5 dark:hover:bg-white/5" : ""}`}
      onClick={onClick ? () => onClick(job) : undefined}
      role={onClick ? "button" : undefined}
      tabIndex={onClick ? 0 : undefined}
      onKeyDown={onClick ? (e) => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); onClick(job); } } : undefined}
      aria-label={onClick ? `Open job ${job.title}` : undefined}
    >
      <div className="min-w-0">
        <div className="flex items-center gap-2">
          <h3 className={`truncate font-medium ${compact ? "text-sm" : "text-sm sm:text-base"}`}>{job.title}</h3>
          <StatusBadge status={job.status} />
        </div>
        <div className={`mt-1 flex items-center gap-2 text-zinc-600 dark:text-zinc-400 ${compact ? "text-xs" : "text-xs sm:text-sm"}`}>
          <Avatar name={job.client.name} />
          <span className="font-medium">{job.client.name}</span>
          <span className="mx-2">•</span>
          <span className="text-zinc-500 dark:text-zinc-400">{job.id}</span>
          <IconButton
            icon="📋"
            label="Copy Job ID"
            onClick={(e) => {
              e.stopPropagation();
              try { navigator.clipboard?.writeText(job.id); } catch {}
            }}
          />
          <span className="mx-2">•</span>
          <span>Budget {formatEth(job.budgetEth)}</span>
          <span className="mx-2">•</span>
          <span>Deadline {formatDate(job.deadline)}</span>
        </div>
      </div>
      <div className="flex shrink-0 items-center gap-2">
        <button
          className={`rounded-full border border-black/10 px-3 ${compact ? "py-0.5 text-xs" : "py-1 text-sm"} transition-colors hover:bg-black/5 dark:border-white/20 dark:hover:bg-white/10`}
          disabled
          title="Submit work (coming soon)"
        >
          Submit Work
        </button>
        <button
          className={`rounded-full border border-black/10 px-3 ${compact ? "py-0.5 text-xs" : "py-1 text-sm"} transition-colors hover:bg-black/5 dark:border-white/20 dark:hover:bg-white/10`}
          disabled
          title="Mark complete (coming soon)"
        >
          Mark Complete
        </button>
        <button
          className={`rounded-full border border-black/10 px-3 ${compact ? "py-0.5 text-xs" : "py-1 text-sm"} transition-colors hover:bg-black/5 dark:border-white/20 dark:hover:bg-white/10`}
          disabled
          title="Message client (coming soon)"
        >
          Message
        </button>
      </div>
    </div>
  );
}
