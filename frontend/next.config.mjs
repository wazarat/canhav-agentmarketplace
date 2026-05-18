/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  experimental: {
    optimizePackageImports: ["lucide-react", "framer-motion"],
  },
  // PostHog ingestion reverse proxy: the SDK posts to `/ingest/*` and we forward
  // to PostHog's US Cloud so ad blockers don't drop requests to *.posthog.com.
  // See https://posthog.com/docs/advanced/proxy/nextjs
  async rewrites() {
    return [
      {
        source: "/ingest/static/:path*",
        destination: "https://us-assets.i.posthog.com/static/:path*",
      },
      {
        source: "/ingest/:path*",
        destination: "https://us.i.posthog.com/:path*",
      },
    ];
  },
  // PostHog API requests have trailing slashes; Next would otherwise redirect.
  skipTrailingSlashRedirect: true,
};

export default nextConfig;
