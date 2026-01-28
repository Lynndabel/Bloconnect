"use client";

export default function Error({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return (
    <div className="mx-auto max-w-7xl px-6 py-10">
      <div className="rounded-2xl border border-rose-200 bg-rose-50 p-6 text-rose-800 dark:border-rose-500/30 dark:bg-rose-950/30 dark:text-rose-300">
        <h2 className="text-lg font-semibold">Something went wrong</h2>
        <p className="mt-1 text-sm opacity-90">{error.message || "Unexpected error loading dashboard."}</p>
        <div className="mt-4 flex items-center gap-2">
          <button
            className="rounded-full border border-black/10 px-4 py-1.5 text-sm transition-colors hover:bg-black/5 dark:border-white/20 dark:hover:bg-white/10"
            onClick={() => reset()}
          >
            Try again
          </button>
        </div>
      </div>
    </div>
  );
}
