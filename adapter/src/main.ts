import { startServer } from "./server.ts";
import type { Source } from "./source.ts";
import { FakeSource } from "./sources/fake.ts";
import { World } from "./world.ts";

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
  throw new Error(`unknown ADAPTER_SOURCE "${name}"`);
}

const world = new World(sourceName);
const source = await makeSource(sourceName);
await source.start(world);
await startServer(world, source, port);
console.log(`[adapter] source=${sourceName} ws://127.0.0.1:${port}/world`);

if (env.ADAPTER_VERBOSE === "1") world.on("message", (m) => console.log(JSON.stringify(m)));

const shutdown = async () => {
  await source.stop();
  process.exit(0);
};
process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
