"use client";

import { ReactNode } from "react";

type Props = {
  title: string;
  description?: string;
  icon?: ReactNode;
  className?: string;
};

export default function EmptyState({ title, description, icon, className = "" }: Props) {
  return (
    <div className={`rounded-2xl border border-dashed border-black/10 p-8 text-center text-sm text-zinc-600 dark:border-white/20 dark:text-zinc-400 ${className}`}>
      <div className="mb-2 text-2xl" aria-hidden>
        {icon ?? "🗂️"}
      </div>
      <div className="font-medium text-zinc-800 dark:text-zinc-200">{title}</div>
      {description && <div className="mt-1 text-zinc-600 dark:text-zinc-400">{description}</div>}
    </div>
  );
}
