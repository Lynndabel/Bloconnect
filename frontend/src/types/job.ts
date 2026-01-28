export type JobStatus = "active" | "pending" | "completed" | "disputed";

export interface Job {
  id: string;
  title: string;
  client: {
    name: string;
    avatarUrl?: string;
  };
  budgetEth: number;
  deadline: string; // ISO date
  status: JobStatus;
}
