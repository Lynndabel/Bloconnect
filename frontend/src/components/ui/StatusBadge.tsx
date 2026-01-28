"use client";

import { HTMLAttributes } from "react";
import { JobStatus } from "@/types/job";

type Props = HTMLAttributes<HTMLSpanElement> & {
  status: JobStatus;
};

const styles: Record<JobStatus, string> = {
  active:
    "bg-sky-100 text-sky-700 border-sky-200 dark:bg-sky-500/10 dark:text-sky-300 dark:border-sky-500/20",
  pending:
    "bg-amber-100 text-amber-800 border-amber-200 dark:bg-amber-500/10 dark:text-amber-300 dark:border-amber-500/20",
  completed:
    "bg-emerald-100 text-emerald-800 border-emerald-200 dark:bg-emerald-500/10 dark:text-emerald-300 dark:border-emerald-500/20",
  disputed:
    "bg-rose-100 text-rose-800 border-rose-200 dark:bg-rose-500/10 dark:text-rose-300 dark:border-rose-500/20",
};

export default function StatusBadge({ status, className = "", ...rest }: Props) {
  return (
    <span
      className={`inline-flex items-center rounded-full border px-2 py-0.5 text-xs font-medium ${styles[status]} ${className}`}
      {...rest}
    >
      {status.charAt(0).toUpperCase() + status.slice(1)}
    </span>
  );
}
