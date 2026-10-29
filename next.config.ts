import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  outputFileTracingExcludes: {'/*':['./work/**/*','./outputs/**/*','./.env*','./.git/**/*']},
  ...(process.env.VERCEL ? {} : { output: "standalone" as const }),
};

export default nextConfig;
