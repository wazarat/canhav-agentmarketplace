export function Background() {
  return (
    <div
      aria-hidden
      className="pointer-events-none fixed inset-0 -z-10 overflow-hidden"
    >
      <div className="absolute inset-0 grid-bg" />
      <div className="absolute -top-40 left-1/2 h-[640px] w-[1100px] -translate-x-1/2 rounded-full bg-electric-500/15 blur-[140px] animate-pulse-soft" />
      <div className="absolute right-[-180px] top-[10%] h-[420px] w-[420px] rounded-full bg-neon-500/15 blur-[120px] animate-blob" />
      <div className="absolute left-[-140px] top-[35%] h-[360px] w-[360px] rounded-full bg-signal-500/10 blur-[120px] animate-blob [animation-delay:-6s]" />
    </div>
  );
}
