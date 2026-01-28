"use client";

import Image from "next/image";

type Props = {
  name: string;
  src?: string;
  size?: number;
  className?: string;
};

export default function Avatar({ name, src, size = 28, className = "" }: Props) {
  const initials = name
    .split(" ")
    .map((n) => n[0])
    .slice(0, 2)
    .join("")
    .toUpperCase();

  if (src) {
    return (
      <Image
        src={src}
        alt={name}
        width={size}
        height={size}
        className={`inline-block rounded-full object-cover ${className}`}
      />
    );
  }

  return (
    <span
      className={`inline-flex items-center justify-center rounded-full bg-black/10 text-[11px] font-medium text-zinc-700 dark:bg-white/10 dark:text-zinc-200 ${className}`}
      style={{ width: size, height: size }}
      aria-label={name}
      title={name}
    >
      {initials}
    </span>
  );
}
