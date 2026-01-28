import Link from "next/link";
import SummaryCards from "@/components/dashboard/SummaryCards";
import JobsList from "@/components/jobs/JobsList";
import PageHeader from "@/components/layout/PageHeader";

export const metadata = {
  title: "Artisan Dashboard · Bloconnect",
  description: "Manage artisan jobs, earnings, and availability on Bloconnect.",
};

export default function ArtisanDashboardPage() {
  return (
    <div className="min-h-screen">
      <div className="mx-auto max-w-7xl px-6 py-10">
        <PageHeader
          title="Artisan Dashboard"
          subtitle="Overview of your jobs, earnings, and account status."
          actions={
            <>
              <Link
                href="/artisans"
                className="inline-flex h-10 items-center justify-center rounded-full border border-black/10 px-4 text-sm transition-colors hover:bg-black/5 dark:border-white/20 dark:hover:bg-white/10"
              >
                Browse marketplace
              </Link>
              <Link
                href="/jobs"
                className="inline-flex h-10 items-center justify-center rounded-full bg-black px-4 text-sm text-white transition-colors hover:bg-zinc-800 dark:bg-zinc-50 dark:text-black dark:hover:bg-zinc-300"
              >
                My jobs
              </Link>
            </>
          }
        />

        <SummaryCards />

        <JobsList />
      </div>
    </div>
  );
}
