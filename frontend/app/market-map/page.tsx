import type { Metadata } from "next";

import { ComingSoonShell } from "@/components/layout/ComingSoonShell";

export const metadata: Metadata = {
  title: "Market Map",
  description:
    "A live, searchable map of hundreds of projects building across the blockchain ecosystem — accelerating your web3 product research and development.",
};

export default function MarketMapPage() {
  return (
    <ComingSoonShell
      eyebrow="Market Map · Coming soon"
      source="market-map"
      title={
        <>
          Hundreds of projects, one{" "}
          <span className="text-gradient-brand">live map</span> of the
          ecosystem.
        </>
      }
      description="We're cataloguing hundreds of projects building across the blockchain ecosystem so you can accelerate your web3 product research and development. Search by sector, status, traction, and team — without scrolling crypto Twitter."
      badges={["Infra", "DeFi", "AI Agents", "Wallets", "Identity", "Data"]}
      bullets={[
        "500+ projects across the major sectors of web3",
        "Filter by sector, chain, stage, and traction signals",
        "Curated by the CanHav research team — refreshed weekly",
        "API access for power users and downstream tools",
      ]}
    />
  );
}
