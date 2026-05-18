"use client";

import posthog from "posthog-js";
import { PostHogProvider as PHProvider } from "posthog-js/react";
import { useEffect } from "react";

import { PostHogPageView } from "./PostHogPageView";

let initialized = false;

export function PostHogProvider({ children }: { children: React.ReactNode }) {
  useEffect(() => {
    if (initialized) return;
    const key = process.env.NEXT_PUBLIC_POSTHOG_KEY;
    if (!key) {
      if (process.env.NODE_ENV === "development") {
        console.warn(
          "[PostHog] NEXT_PUBLIC_POSTHOG_KEY is not set, analytics disabled.",
        );
      }
      return;
    }

    initialized = true;
    posthog.init(key, {
      api_host: "/ingest",
      ui_host:
        process.env.NEXT_PUBLIC_POSTHOG_HOST ?? "https://us.posthog.com",
      defaults: "2026-01-30",
      capture_pageview: false,
      capture_pageleave: true,
      capture_exceptions: true,
      person_profiles: "identified_only",
      loaded: (ph) => {
        if (process.env.NODE_ENV === "development") ph.debug();
      },
    });
  }, []);

  return (
    <PHProvider client={posthog}>
      <PostHogPageView />
      {children}
    </PHProvider>
  );
}
