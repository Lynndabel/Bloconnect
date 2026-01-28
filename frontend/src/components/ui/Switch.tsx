"use client";

import { HTMLAttributes } from "react";

type Props = Omit<HTMLAttributes<HTMLButtonElement>, "onChange"> & {
  checked: boolean;
  onChange: (v: boolean) => void;
};

export default function Switch({ checked, onChange, className = "", ...rest }: Props) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      onClick={() => onChange(!checked)}
      className={`inline-flex h-6 w-11 items-center rounded-full border border-black/10 p-0.5 transition-colors dark:border-white/20 ${
        checked ? "bg-black dark:bg-zinc-50" : "bg-transparent"
      } ${className}`}
      {...rest}
    >
      <span
        className={`h-5 w-5 rounded-full bg-white shadow transition-transform dark:bg-black ${
          checked ? "translate-x-5" : "translate-x-0"
        }`}
      />
    </button>
  );
}
