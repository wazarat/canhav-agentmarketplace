interface ErrorPanelProps {
  title: string;
  detail?: string;
}

export function ErrorPanel({ title, detail }: ErrorPanelProps) {
  return (
    <div className="glass rounded-2xl border border-amber-500/30 bg-amber-500/5 p-6 text-sm text-ink-100">
      <p className="font-mono text-[11px] uppercase tracking-wider text-amber-400">{title}</p>
      {detail && <p className="mt-2 text-ink-300">{detail}</p>}
    </div>
  );
}
