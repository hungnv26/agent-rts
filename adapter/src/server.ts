import { createServer, type IncomingMessage, type Server, type ServerResponse } from "node:http";
import { WebSocketServer, type WebSocket } from "ws";
import type { ClientCommand, ServerMessage } from "./contract.ts";
import type { Source } from "./source.ts";
import type { World } from "./world.ts";

const MAX_TITLE = 300;

export function parseCommand(raw: string): ClientCommand | null {
  let m: unknown;
  try {
    m = JSON.parse(raw);
  } catch {
    return null;
  }
  if (!m || typeof m !== "object") return null;
  const c = m as Record<string, unknown>;
  switch (c.type) {
    case "hello":
      return { type: "hello", client: String(c.client ?? "unknown") };
    case "mission.create": {
      const title = typeof c.title === "string" ? c.title.trim().slice(0, MAX_TITLE) : "";
      return title ? { type: "mission.create", title } : null;
    }
    case "approval.resolve":
      return typeof c.id === "string" && typeof c.approved === "boolean"
        ? { type: "approval.resolve", id: c.id, approved: c.approved }
        : null;
    case "mission.cancel":
      return { type: "mission.cancel" };
    case "replay.request":
      return typeof c.missionId === "string" ? { type: "replay.request", missionId: c.missionId } : { type: "replay.request" };
    default:
      return null;
  }
}

// HTTP (health, state, commands for scripts) + WebSocket (/world) for game clients.
export function startServer(world: World, source: Source, port: number, host = "127.0.0.1"): Promise<Server> {
  const clients = new Set<WebSocket>();

  const handle = async (cmd: ClientCommand): Promise<void> => {
    switch (cmd.type) {
      case "hello":
        world.logLine(`Client connected: ${cmd.client}`);
        return;
      case "mission.create":
        return source.createMission(cmd.title);
      case "approval.resolve":
        return source.resolveApproval(cmd.id, cmd.approved);
      case "mission.cancel":
        return source.cancelMission();
      case "replay.request":
        return; // answered per client (WebSocket) or via GET /replay
    }
  };

  const http = createServer(async (req: IncomingMessage, res: ServerResponse) => {
    const json = (code: number, body: unknown) => {
      res.writeHead(code, { "content-type": "application/json" });
      res.end(JSON.stringify(body));
    };
    if (req.method === "GET" && req.url === "/health") return json(200, { ok: true, source: source.name, clients: clients.size });
    if (req.method === "GET" && req.url === "/state") return json(200, { seq: world.currentSeq, world: world.snapshot() });
    if (req.method === "GET" && req.url?.startsWith("/replay")) {
      const missionId = new URL(req.url, "http://x").searchParams.get("missionId") ?? undefined;
      const replay = world.replay(missionId);
      return replay ? json(200, replay) : json(404, { error: "no recorded mission" });
    }
    if (req.method === "POST" && req.url === "/command") {
      let body = "";
      for await (const chunk of req) body += chunk;
      const cmd = parseCommand(body);
      if (!cmd) return json(400, { error: "invalid command" });
      try {
        await handle(cmd);
        return json(200, { ok: true });
      } catch (e) {
        return json(500, { error: String(e) });
      }
    }
    json(404, { error: "not found" });
  });

  const wss = new WebSocketServer({ server: http, path: "/world" });
  wss.on("connection", (ws) => {
    clients.add(ws);
    ws.send(JSON.stringify({ type: "snapshot", seq: world.currentSeq, world: world.snapshot() } satisfies ServerMessage));
    ws.on("message", (data) => {
      const cmd = parseCommand(data.toString());
      if (!cmd) {
        ws.send(JSON.stringify({ type: "error", seq: world.currentSeq, message: "invalid command" } satisfies ServerMessage));
        return;
      }
      if (cmd.type === "replay.request") {
        const msg: ServerMessage = { type: "replay", seq: world.currentSeq, replay: world.replay(cmd.missionId) };
        ws.send(JSON.stringify(msg));
        return;
      }
      handle(cmd).catch((e) => world.logLine(`Command ${cmd.type} failed: ${e}`, "error"));
    });
    ws.on("close", () => clients.delete(ws));
    ws.on("error", () => clients.delete(ws));
  });

  world.on("message", (msg: ServerMessage) => {
    const text = JSON.stringify(msg);
    for (const ws of clients) if (ws.readyState === ws.OPEN) ws.send(text);
  });

  return new Promise((resolve) => http.listen(port, host, () => resolve(http)));
}
