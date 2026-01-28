"use client";

import { ReactNode } from "react";

type CardProps = {
  title?: ReactNode;
  children?: ReactNode;
  className?: string;
  footer?: ReactNode;
};

export default function Card({ title, children, className = "", footer }: CardProps) {
  return (
    <div className={`rounded-2xl border border-black/10 bg-white/50 p-4 dark:border-white/15 dark:bg-black/30 ${className}`}>
      {title && <div className="text-sm text-zinc-600 dark:text-zinc-400">{title}</div>}
      {children && <div className={title ? "mt-2" : ""}>{children}</div>}
      {footer && <div className="mt-3 border-t border-black/10 pt-3 text-sm dark:border-white/10">{footer}</div>}
    </div>
  );
}
