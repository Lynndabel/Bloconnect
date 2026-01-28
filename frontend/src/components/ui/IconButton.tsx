"use client";

import { ButtonHTMLAttributes, ReactNode } from "react";

type Props = ButtonHTMLAttributes<HTMLButtonElement> & {
  icon: ReactNode;
  label: string;
};

export default function IconButton({ icon, label, className = "", ...rest }: Props) {
  return (
    <button
      type="button"
      aria-label={label}
      title={label}
      className={`inline-flex items-center justify-center rounded-full border border-black/10 p-1.5 text-sm transition-colors hover:bg-black/5 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-black/40 dark:border-white/20 dark:hover:bg-white/10 dark:focus-visible:ring-white/40 ${className}`}
      {...rest}
    >
      <span aria-hidden>{icon}</span>
    </button>
  );
}
