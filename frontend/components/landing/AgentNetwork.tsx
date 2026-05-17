"use client";

import { motion } from "framer-motion";

/**
 * Decorative "agent network" SVG used in the hero. Pure CSS/SVG — no heavy 3D.
 * Nodes pulse, connections shimmer, the whole thing rotates very gently.
 */
export function AgentNetwork() {
  const nodes = [
    { x: 50, y: 50, r: 18, label: "core" },
    { x: 18, y: 22, r: 8 },
    { x: 82, y: 18, r: 9 },
    { x: 14, y: 76, r: 9 },
    { x: 84, y: 78, r: 8 },
    { x: 50, y: 8, r: 6 },
    { x: 50, y: 92, r: 6 },
    { x: 6, y: 50, r: 6 },
    { x: 94, y: 50, r: 7 },
  ];

  const edges: Array<[number, number]> = [
    [0, 1], [0, 2], [0, 3], [0, 4],
    [0, 5], [0, 6], [0, 7], [0, 8],
    [1, 5], [2, 5], [3, 6], [4, 6],
    [1, 7], [2, 8], [3, 7], [4, 8],
  ];

  return (
    <div className="relative aspect-square w-full max-w-[520px]">
      <div className="absolute inset-0 -z-10 rounded-full bg-electric-500/10 blur-3xl" />

      <motion.div
        animate={{ rotate: [0, 360] }}
        transition={{ duration: 80, repeat: Infinity, ease: "linear" }}
        className="absolute inset-0"
      >
        <svg viewBox="0 0 100 100" className="h-full w-full">
          <defs>
            <radialGradient id="coreGrad" cx="50%" cy="50%" r="50%">
              <stop offset="0%" stopColor="#A78BFA" stopOpacity="0.95" />
              <stop offset="60%" stopColor="#3D7BFF" stopOpacity="0.6" />
              <stop offset="100%" stopColor="#3D7BFF" stopOpacity="0" />
            </radialGradient>
            <linearGradient id="lineGrad" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" stopColor="#3D7BFF" stopOpacity="0.0" />
              <stop offset="50%" stopColor="#22D3EE" stopOpacity="0.7" />
              <stop offset="100%" stopColor="#8B5CF6" stopOpacity="0.0" />
            </linearGradient>
            <radialGradient id="nodeGrad" cx="50%" cy="40%" r="60%">
              <stop offset="0%" stopColor="#ffffff" stopOpacity="0.95" />
              <stop offset="60%" stopColor="#5C92FF" stopOpacity="0.6" />
              <stop offset="100%" stopColor="#3D7BFF" stopOpacity="0" />
            </radialGradient>
          </defs>

          {/* outer rings */}
          <circle cx="50" cy="50" r="46" fill="none" stroke="rgba(124,132,153,0.15)" strokeWidth="0.2" strokeDasharray="0.6 0.8" />
          <circle cx="50" cy="50" r="36" fill="none" stroke="rgba(124,132,153,0.18)" strokeWidth="0.2" strokeDasharray="0.4 0.6" />
          <circle cx="50" cy="50" r="26" fill="none" stroke="rgba(124,132,153,0.22)" strokeWidth="0.2" />

          {/* edges */}
          {edges.map(([a, b], i) => (
            <motion.line
              key={i}
              x1={nodes[a].x}
              y1={nodes[a].y}
              x2={nodes[b].x}
              y2={nodes[b].y}
              stroke="url(#lineGrad)"
              strokeWidth="0.35"
              initial={{ pathLength: 0, opacity: 0.2 }}
              animate={{ pathLength: 1, opacity: [0.2, 0.7, 0.2] }}
              transition={{
                duration: 4,
                repeat: Infinity,
                delay: i * 0.18,
                ease: "easeInOut",
              }}
            />
          ))}

          {/* nodes */}
          {nodes.map((n, i) => (
            <g key={i}>
              {i === 0 && (
                <motion.circle
                  cx={n.x}
                  cy={n.y}
                  r={n.r * 1.6}
                  fill="url(#coreGrad)"
                  animate={{ scale: [1, 1.05, 1], opacity: [0.7, 1, 0.7] }}
                  transition={{ duration: 3.5, repeat: Infinity, ease: "easeInOut" }}
                  style={{ transformOrigin: `${n.x}px ${n.y}px` }}
                />
              )}
              <motion.circle
                cx={n.x}
                cy={n.y}
                r={n.r * 0.5}
                fill={i === 0 ? "url(#nodeGrad)" : "url(#nodeGrad)"}
                animate={{ opacity: [0.6, 1, 0.6] }}
                transition={{
                  duration: 2.6 + (i % 3),
                  repeat: Infinity,
                  delay: i * 0.2,
                  ease: "easeInOut",
                }}
              />
              <circle
                cx={n.x}
                cy={n.y}
                r={Math.max(n.r * 0.16, 0.6)}
                fill="#ffffff"
                opacity={0.95}
              />
            </g>
          ))}
        </svg>
      </motion.div>

      {/* corner labels */}
      <div className="pointer-events-none absolute left-3 top-3 font-mono text-[10px] uppercase tracking-wider text-ink-300">
        agent intelligence
      </div>
      <div className="pointer-events-none absolute right-3 top-3 font-mono text-[10px] uppercase tracking-wider text-ink-300">
        web3 market map
      </div>
      <div className="pointer-events-none absolute bottom-3 right-3 font-mono text-[10px] uppercase tracking-wider text-ink-300">
        on-chain rails
      </div>
    </div>
  );
}
