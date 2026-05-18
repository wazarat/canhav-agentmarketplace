import type { Metadata, Viewport } from "next";
import { Inter, Space_Grotesk, JetBrains_Mono } from "next/font/google";
import { Toaster } from "sonner";

import { Background } from "@/components/layout/Background";
import { Footer } from "@/components/layout/Footer";
import { Nav } from "@/components/layout/Nav";
import { PostHogProvider } from "@/components/providers/PostHogProvider";
import { SITE } from "@/lib/utils";

import "./globals.css";

const sans = Inter({
  subsets: ["latin"],
  display: "swap",
  variable: "--font-sans",
});

const display = Space_Grotesk({
  subsets: ["latin"],
  display: "swap",
  variable: "--font-display",
});

const mono = JetBrains_Mono({
  subsets: ["latin"],
  display: "swap",
  variable: "--font-mono",
});

const DESCRIPTION =
  "Use CanHav to research blockchain ecosystems, train smarter agents, and turn AI agent workflows into products that can be deployed and monetized on-chain.";

const SHARE_TITLE = `${SITE.name}: ${SITE.tagline}`;

export const metadata: Metadata = {
  metadataBase: new URL(SITE.url),
  title: {
    default: SHARE_TITLE,
    template: `%s · ${SITE.name}`,
  },
  description: DESCRIPTION,
  keywords: [
    "ai agents",
    "web3",
    "crypto",
    "agent marketplace",
    "ethereum",
    "arbitrum",
    "research",
    "canhav",
  ],
  icons: {
    icon: [
      { url: "/favicon.png", type: "image/png" },
      { url: "/icon-192.png", sizes: "192x192", type: "image/png" },
      { url: "/icon-512.png", sizes: "512x512", type: "image/png" },
    ],
    apple: [{ url: "/apple-touch-icon.png", sizes: "180x180", type: "image/png" }],
    shortcut: [{ url: "/favicon.png", type: "image/png" }],
  },
  openGraph: {
    title: SHARE_TITLE,
    description: DESCRIPTION,
    url: SITE.url,
    siteName: SITE.name,
    type: "website",
    images: [
      {
        url: "/og-image.png",
        width: 1200,
        height: 630,
        alt: SHARE_TITLE,
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: SHARE_TITLE,
    description: DESCRIPTION,
    images: ["/og-image.png"],
  },
};

export const viewport: Viewport = {
  themeColor: "#05060A",
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html
      lang="en"
      className={`${sans.variable} ${display.variable} ${mono.variable} dark`}
      suppressHydrationWarning
    >
      <body className="min-h-screen overflow-x-hidden">
        <PostHogProvider>
          <Background />
          <Nav />
          <main className="pt-24">{children}</main>
          <Footer />
          <Toaster
            theme="dark"
            position="top-center"
            toastOptions={{
              classNames: {
                toast:
                  "!bg-ink-900/90 !text-ink-50 !border-ink-700/80 backdrop-blur-md",
              },
            }}
          />
        </PostHogProvider>
      </body>
    </html>
  );
}
