"use client";

import { ButtonHTMLAttributes } from "react";

type PillButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  active?: boolean;
};

export default function PillButton({ active = false, className = "", ...props }: PillButtonProps) {
  const base = "rounded-full border px-3 py-1 text-sm transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-black/40 dark:focus-visible:ring-white/40";
  const light = active
    ? "bg-black text-white border-black/10 dark:bg-zinc-50 dark:text-black"
    : "border-black/10 hover:bg-black/5 dark:border-white/20 dark:hover:bg-white/10";
  return <button aria-pressed={active} className={`${base} ${light} ${className}`} {...props} />;
}
