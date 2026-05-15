import * as React from "react";
import { cn } from "@/lib/utils";

export type InputProps = React.InputHTMLAttributes<HTMLInputElement>;

export const Input = React.forwardRef<HTMLInputElement, InputProps>(
  ({ className, type = "text", ...props }, ref) => {
    return (
      <input
        ref={ref}
        type={type}
        className={cn(
          "h-11 w-full rounded-full bg-ink-900/70 px-5 text-sm text-ink-50 placeholder:text-ink-300/70",
          "border border-ink-700/80 transition-all",
          "focus:border-electric-500 focus:outline-none focus:ring-2 focus:ring-electric-500/40",
          "disabled:cursor-not-allowed disabled:opacity-60",
          className,
        )}
        {...props}
      />
    );
  },
);
Input.displayName = "Input";
