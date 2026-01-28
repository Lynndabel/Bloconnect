"use client";

type Props = {
  page: number;
  totalPages: number;
  label?: string;
  onPrev: () => void;
  onNext: () => void;
};

export default function Pagination({ page, totalPages, label, onPrev, onNext }: Props) {
  return (
    <div className="mt-4 flex items-center justify-between text-sm text-zinc-600 dark:text-zinc-400">
      <div>{label}</div>
      <div className="flex items-center gap-2">
        <button
          className="rounded-full border border-black/10 px-3 py-1 transition-colors hover:bg-black/5 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-black/40 disabled:opacity-50 dark:border-white/20 dark:hover:bg-white/10 dark:focus-visible:ring-white/40"
          onClick={onPrev}
          disabled={page === 1}
        >
          Prev
        </button>
        <span>
          Page {page} / {totalPages}
        </span>
        <button
          className="rounded-full border border-black/10 px-3 py-1 transition-colors hover:bg-black/5 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-black/40 disabled:opacity-50 dark:border-white/20 dark:hover:bg-white/10 dark:focus-visible:ring-white/40"
          onClick={onNext}
          disabled={page === totalPages}
        >
          Next
        </button>
      </div>
    </div>
  );
}
