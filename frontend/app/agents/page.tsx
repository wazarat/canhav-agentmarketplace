import type { Metadata } from "next";

import { ComingSoonShell } from "@/components/layout/ComingSoonShell";

export const metadata: Metadata = {
  title: "Agents",
  description:
    "Train your AI agent on the CanHav stack — we provide everything it needs to be trained, then help you monetize it through the upcoming AI agent marketplace on Arbitrum.",
};

export default function AgentsPage() {
  return (
    <ComingSoonShell
      eyebrow="Agents · Coming soon"
      source="agents"
      title={
        <>
          Train your agent. Ship it.{" "}
          <span className="text-gradient-brand">Get paid on-chain.</span>
        </>
      }
      description="Bring your agent. We'll provide everything it needs to train — datasets, evals, infra, tooling — and then help you monetize it through our upcoming AI agent marketplace, with payments settled on Arbitrum."
      badges={["Bring-your-own-model", "Evals", "Datasets", "Arbitrum payments"]}
      bullets={[
        "Bring-your-own-model. We handle data, evals, and tooling.",
        "Reference infra primitives for memory, tools, and orchestration",
        "List your agent in the CanHav marketplace at launch",
        "On-chain settlement on Arbitrum — agents can pay other agents",
      ]}
    />
  );
}
