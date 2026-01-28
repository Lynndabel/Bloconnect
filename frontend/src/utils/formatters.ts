export function formatEth(v: number) {
  try {
    return `Ξ ${v.toLocaleString(undefined, { maximumFractionDigits: 4 })}`;
  } catch {
    return `Ξ ${v}`;
  }
}

export function formatDate(iso: string) {
  try {
    const d = new Date(iso);
    return d.toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" });
  } catch {
    return iso;
  }
}
