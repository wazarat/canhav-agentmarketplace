import { cn } from "@/lib/utils";

export function Logo({ className }: { className?: string }) {
  return (
    <span className={cn("inline-flex items-center gap-2", className)}>
      <span className="relative inline-block h-7 w-7">
        <span className="absolute inset-0 rounded-md bg-gradient-to-br from-electric-500 via-neon-500 to-signal-500 opacity-90" />
        <span className="absolute inset-[2px] rounded-[5px] bg-ink-950" />
        <span className="absolute inset-0 grid place-items-center font-display text-[14px] font-bold leading-none text-white">
          C
        </span>
        <span className="absolute -inset-1 -z-10 rounded-lg bg-electric-500/20 blur-md" />
      </span>
      <span className="font-display text-base font-semibold tracking-tight text-ink-50">
        CanHav
      </span>
    </span>
  );
}
