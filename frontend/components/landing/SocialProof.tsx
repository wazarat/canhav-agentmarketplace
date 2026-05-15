export function SocialProof() {
  const items = [
    "ETHEREUM",
    "ARBITRUM",
    "BASE",
    "SOLANA",
    "OPTIMISM",
    "POLYGON",
  ];
  return (
    <section className="container py-10">
      <p className="text-center text-xs uppercase tracking-[0.2em] text-ink-300">
        Built by researchers shipping across the ecosystem
      </p>
      <div className="mt-6 flex flex-wrap items-center justify-center gap-x-10 gap-y-4 opacity-70">
        {items.map((item) => (
          <span
            key={item}
            className="font-display text-sm font-semibold tracking-[0.18em] text-ink-100/80"
          >
            {item}
          </span>
        ))}
      </div>
    </section>
  );
}
