import { existsSync } from "node:fs";
import { startServer } from "./server.ts";
import type { Source } from "./source.ts";
import { FakeSource } from "./sources/fake.ts";
import { HermesSource } from "./sources/hermes.ts";
import { MissionControlSink } from "./sinks/mission-control.ts";
import { World } from "./world.ts";

// Settings come from the environment, falling back to the repo's .env (scripts/gen-env.sh).
const dotenv = new URL("../../.env", import.meta.url);
if (existsSync(dotenv)) process.loadEnvFile(dotenv);

const env = process.env;
const port = Number(env.ADAPTER_PORT ?? 8770);
const sourceName = env.ADAPTER_SOURCE ?? "fake";

async function makeSource(name: string): Promise<Source> {
  if (name === "fake") {
    return new FakeSource({
      speed: Number(env.FAKE_SPEED ?? 1),
      loop: env.FAKE_LOOP === "1",
      autoApproveMs: env.FAKE_AUTO_APPROVE_MS === "off" ? null : Number(env.FAKE_AUTO_APPROVE_MS ?? 20000),
    });
  }
  if (name === "hermes") {
    return new HermesSource({
      baseUrl: env.HERMES_URL ?? "http://127.0.0.1:8100",
      token: env.HERMES_TOKEN ?? "dev_master_token",
      requireApproval: env.ADAPTER_REQUIRE_APPROVAL !== "0",
      costBudgetUsd: env.ADAPTER_COST_BUDGET_USD ? Number(env.ADAPTER_COST_BUDGET_USD) : 0.5,
    });
  }
  throw new Error(`unknown ADAPTER_SOURCE "${name}"`);
}

const world = new World(sourceName);
const source = await makeSource(sourceName);
await source.start(world);

let sink: MissionControlSink | null = null;
if (env.MC_URL && env.MC_API_KEY && env.MC_SYNC !== "0") {
  sink = new MissionControlSink({
    url: env.MC_URL.replace(/\/$/, ""),
    apiKey: env.MC_API_KEY,
    model: env.ADAPTER_MODEL_LABEL ?? "agentrts-qwen3",
    onApproval: (id, approved) => void source.resolveApproval(id, approved),
  });
  await sink.start(world);
}

await startServer(world, source, port);
console.log(`[adapter] source=${sourceName} ws://127.0.0.1:${port}/world mission-control=${sink ? env.MC_URL : "off"}`);

if (env.ADAPTER_VERBOSE === "1") world.on("message", (m) => console.log(JSON.stringify(m)));

const shutdown = async () => {
  sink?.stop();
  await source.stop();
  process.exit(0);
};
process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
