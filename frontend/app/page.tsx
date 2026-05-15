import { FAQ } from "@/components/landing/FAQ";
import { Features } from "@/components/landing/Features";
import { Hero } from "@/components/landing/Hero";
import { Roadmap } from "@/components/landing/Roadmap";
import { SocialProof } from "@/components/landing/SocialProof";
import { ValueProps } from "@/components/landing/ValueProps";
import { WaitlistSection } from "@/components/landing/WaitlistSection";

export default function HomePage() {
  return (
    <>
      <Hero />
      <SocialProof />
      <ValueProps />
      <Features />
      <Roadmap />
      <WaitlistSection />
      <FAQ />
    </>
  );
}
