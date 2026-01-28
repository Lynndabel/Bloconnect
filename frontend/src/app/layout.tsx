import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import Link from "next/link";
import ThemeToggle from "@/components/ThemeToggle";
import Script from "next/script";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Bloconnect · Hire verified artisans on Base",
  description: "Escrowed job payments with timeouts, disputes, and verified artisans on Base.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" data-theme="light">
      <body className={`${geistSans.variable} ${geistMono.variable} antialiased`}>
        <Script id="init-theme" strategy="beforeInteractive">
          {`
            (function(){
              try {
                var de = document.documentElement;
                // Force light theme on initial load and persist it
                var theme = 'light';
                de.dataset.theme = theme;
                de.classList.remove('dark');
                try { localStorage.setItem('theme', theme); } catch (_) {}
              } catch (e) {
                document.documentElement.dataset.theme = 'light';
                document.documentElement.classList.remove('dark');
              }
            })();
          `}
        </Script>
        <div className="mx-auto max-w-7xl px-6">
          <header className="flex items-center justify-between py-5">
            <Link href="/" className="flex items-center gap-2 text-base font-semibold focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-black/40 dark:focus-visible:ring-white/40 rounded">
              <span className="inline-flex h-6 w-6 items-center justify-center rounded bg-black text-white dark:bg-zinc-50 dark:text-black">B</span>
              <span>Bloconnect</span>
            </Link>
            <nav className="flex items-center gap-4 text-sm">
              <Link href="#how-it-works" className="transition-colors hover:opacity-80 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-black/40 dark:focus-visible:ring-white/40 rounded">How it works</Link>
              <Link href="/artisans" className="transition-colors hover:opacity-80 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-black/40 dark:focus-visible:ring-white/40 rounded">Artisans</Link>
              <Link href="/dashboard/artisan" className="transition-colors hover:opacity-80 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-black/40 dark:focus-visible:ring-white/40 rounded">Dashboard</Link>
              <Link href="/jobs" className="transition-colors hover:opacity-80 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-black/40 dark:focus-visible:ring-white/40 rounded">My Jobs</Link>
              <Link href="/admin" className="transition-colors hover:opacity-80 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-black/40 dark:focus-visible:ring-white/40 rounded">Admin</Link>
              <ThemeToggle />
            </nav>
          </header>
        </div>
        {children}
        <footer className="mt-20 border-t border-black/10 py-10 text-sm text-zinc-600 dark:border-white/15 dark:text-zinc-400">
          <div className="mx-auto max-w-7xl px-6 flex flex-col items-center gap-2 sm:flex-row sm:justify-between">
            <span>© {new Date().getFullYear()} Bloconnect</span>
            <div className="flex items-center gap-4">
              <Link href="#how-it-works" className="hover:opacity-80">How it works</Link>
              <a href="https://base.org" target="_blank" rel="noreferrer" className="hover:opacity-80">Built for Base</a>
            </div>
          </div>
        </footer>
      </body>
    </html>
  );
}
