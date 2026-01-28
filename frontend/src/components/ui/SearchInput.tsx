"use client";

import { InputHTMLAttributes } from "react";

type Props = InputHTMLAttributes<HTMLInputElement>;

export default function SearchInput({ className = "", ...rest }: Props) {
  return (
    <input
      type="text"
      className={`w-full rounded-full border border-black/10 px-4 py-2 text-sm outline-none transition-colors placeholder:text-zinc-400 focus:border-black/30 dark:border-white/20 dark:focus:border-white/40 ${className}`}
      {...rest}
    />
  );
}
