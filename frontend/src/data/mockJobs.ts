import { Job } from "@/types/job";

export const mockJobs: Job[] = [
  {
    id: "J-1001",
    title: "Landing page redesign",
    client: { name: "Acme Corp" },
    budgetEth: 0.35,
    deadline: new Date(Date.now() + 1000 * 60 * 60 * 24 * 7).toISOString(),
    status: "active",
  },
  {
    id: "J-1002",
    title: "Logo vectorization",
    client: { name: "Bright Studio" },
    budgetEth: 0.12,
    deadline: new Date(Date.now() + 1000 * 60 * 60 * 24 * 3).toISOString(),
    status: "pending",
  },
  {
    id: "J-1003",
    title: "E-commerce product photos",
    client: { name: "Shopbase" },
    budgetEth: 1.2,
    deadline: new Date(Date.now() - 1000 * 60 * 60 * 24 * 1).toISOString(),
    status: "completed",
  },
  {
    id: "J-1004",
    title: "Mobile app UI kit",
    client: { name: "Nova Labs" },
    budgetEth: 0.8,
    deadline: new Date(Date.now() + 1000 * 60 * 60 * 24 * 14).toISOString(),
    status: "disputed",
  },
];
