import Image from "next/image";

import type { ProjectRow } from "@/lib/market-map";

type Size = "sm" | "md" | "lg";

interface ProjectLogoProps {
  project: Pick<ProjectRow, "name" | "logo_url" | "sector_attributes"> & { name: string };
  size?: Size;
  className?: string;
}

/**
 * Consistent logo treatment for every project row, card, and detail page.
 *
 * Design rules (kept in lockstep with .cursor/skills/market-map/LOGOS.md):
 *  - Always rendered inside a rounded neutral-background tile. Stops light/dark/colored
 *    logos from each fighting the page background.
 *  - object-contain — never crop or distort the source mark.
 *  - Falls back to a 2-letter monogram derived from the project name when logo_url is null.
 *    Same tile shape and size, so layout never shifts when logos arrive late.
 *  - Sizes: sm = 28px (tables / list rows), md = 48px (canonical hero card), lg = 80px (project detail header).
 */
export function ProjectLogo({ project, size = "sm", className }: ProjectLogoProps) {
  const dimensions: Record<Size, { box: string; img: number; textClass: string; radius: string }> = {
    sm: { box: "h-7 w-7", img: 28, textClass: "text-[10px]", radius: "rounded-md" },
    md: { box: "h-12 w-12", img: 48, textClass: "text-sm", radius: "rounded-lg" },
    lg: { box: "h-20 w-20", img: 80, textClass: "text-xl", radius: "rounded-xl" },
  };
  const d = dimensions[size];
  const monogram = makeMonogram(project.name);

  const containerClass = [
    d.box,
    d.radius,
    "relative shrink-0 overflow-hidden border border-ink-700/60 bg-ink-800/70 backdrop-blur-sm",
    "flex items-center justify-center",
    className ?? "",
  ]
    .filter(Boolean)
    .join(" ");

  if (project.logo_url) {
    return (
      <div className={containerClass} aria-hidden={false}>
        <Image
          src={project.logo_url}
          alt={`${project.name} logo`}
          width={d.img}
          height={d.img}
          className="h-full w-full object-contain p-[10%]"
          unoptimized
        />
      </div>
    );
  }

  return (
    <div
      className={containerClass}
      role="img"
      aria-label={`${project.name} (no logo)`}
    >
      <span
        className={`font-mono ${d.textClass} font-semibold uppercase tracking-wider text-ink-300`}
      >
        {monogram}
      </span>
    </div>
  );
}

function makeMonogram(name: string): string {
  const words = name
    .replace(/[^a-zA-Z0-9 ]/g, " ")
    .split(/\s+/)
    .filter(Boolean);
  if (words.length === 0) return "?";
  if (words.length === 1) return words[0].slice(0, 2).toUpperCase();
  return (words[0][0] + words[words.length - 1][0]).toUpperCase();
}
