import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export const SITE = {
  name: "CanHav",
  tagline: "Turn web3 research into products your agents can help ship.",
  url: "https://canhav.com",
  research: "https://research.canhav.com",
  socials: {
    x: "https://x.com/wazarat",
    linkedin: "https://www.linkedin.com/in/wazarat",
  },
} as const;
