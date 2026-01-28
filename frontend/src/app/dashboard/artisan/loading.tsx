export default function Loading() {
  return (
    <div className="mx-auto max-w-7xl px-6 py-10">
      <div className="mb-6 h-8 w-56 animate-pulse rounded-md bg-black/10 dark:bg-white/10" />
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <div key={i} className="h-24 animate-pulse rounded-2xl bg-black/10 dark:bg-white/10" />
        ))}
      </div>
      <div className="mt-10 space-y-3">
        {Array.from({ length: 3 }).map((_, i) => (
          <div key={i} className="h-16 animate-pulse rounded-2xl bg-black/10 dark:bg-white/10" />
        ))}
      </div>
    </div>
  );
}
