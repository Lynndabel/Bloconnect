"use client";

import { HTMLAttributes } from "react";

export default function Skeleton({ className = "", ...rest }: HTMLAttributes<HTMLDivElement>) {
  return <div className={`animate-pulse rounded-md bg-black/10 dark:bg-white/10 ${className}`} {...rest} />;
}
