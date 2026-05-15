import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export const SITE = {
  name: "CanHav",
  tagline: "The fastest path from idea to shipped, monetized AI agent.",
  url: "https://canhav.com",
  research: "https://research.canhav.com",
  socials: {
    x: "https://x.com/canhav_research",
    github: "https://github.com/wazarat/canhav-agentmarketplace",
  },
} as const;
