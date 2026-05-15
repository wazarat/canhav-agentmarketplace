import { WaitlistForm } from "@/components/landing/WaitlistForm";

export function WaitlistSection() {
  return (
    <section id="waitlist" className="container scroll-mt-28 py-24">
      <div className="relative mx-auto max-w-3xl overflow-hidden rounded-3xl glass p-8 sm:p-12 glow-ring">
        <div className="pointer-events-none absolute -top-24 left-1/2 h-64 w-[640px] -translate-x-1/2 rounded-full bg-electric-500/20 blur-3xl" />

        <p className="text-center font-mono text-xs uppercase tracking-[0.25em] text-signal-400">
          Stay in the loop
        </p>
        <h2 className="mx-auto mt-3 max-w-xl text-center font-display text-3xl font-semibold tracking-tight text-ink-50 sm:text-4xl">
          Get the next research drop and{" "}
          <span className="text-gradient-brand">early marketplace access</span>.
        </h2>
        <p className="mx-auto mt-4 max-w-md text-center text-ink-300">
          One email when we ship something that matters. No newsletter fluff,
          ever.
        </p>

        <div className="mx-auto mt-8 max-w-xl">
          <WaitlistForm source="landing" />
        </div>
      </div>
    </section>
  );
}
