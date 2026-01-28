import { Job } from "@/types/job";

export function computeStats(jobs: Job[]) {
  const active = jobs.filter((j) => j.status === "active").length;
  const completed = jobs.filter((j) => j.status === "completed");
  const earningsEth = completed.reduce((sum, j) => sum + (j.budgetEth || 0), 0);
  const rating = null as number | null; // placeholder until ratings exist
  return { active, earningsEth, rating };
}
