import { EventEmitter } from "node:events";
import {
  CONTRACT_VERSION,
  type Agent,
  type AgentRole,
  type AgentState,
  type Approval,
  type BuildingId,
  type LocationId,
  type LogLine,
  type Mission,
  type Resources,
  type ServerEvent,
  type ServerMessage,
  type Task,
  type WorldSnapshot,
} from "./contract.ts";

export const ROSTER: { id: string; name: string; role: AgentRole }[] = [
  { id: "researcher", name: "Researcher", role: "researcher" },
  { id: "coder", name: "Coder", role: "coder" },
  { id: "analyst", name: "Analyst", role: "analyst" },
  { id: "reviewer", name: "Reviewer", role: "reviewer" },
];

export const HOME_BUILDING: Record<AgentRole, BuildingId> = {
  researcher: "research_lab",
  coder: "code_factory",
  analyst: "knowledge_library",
  reviewer: "knowledge_library",
};

const LOG_LIMIT = 200;

// Where an agent stands for a given state. `building` only matters while working.
export function locationFor(state: AgentState, role: AgentRole, building?: BuildingId | null, current?: LocationId): LocationId {
  switch (state) {
    case "idle":
    case "complete":
      return "command_centre";
    case "thinking":
      return current ?? "command_centre";
    case "working":
      return building ?? HOME_BUILDING[role];
    case "waiting":
      return "rally_point";
    case "approval":
      return "human_approval";
    case "error":
      return "repair_bay";
  }
}

export interface AgentUpdate {
  state: AgentState;
  building?: BuildingId | null;
  taskId?: string | null;
  taskTitle?: string | null;
  detail?: string | null;
  progress?: number | null;
}

// Single source of truth for what the game shows. Sources write into it; the server
// and sinks subscribe to "message".
export class World extends EventEmitter {
  private seq = 0;
  private agents = new Map<string, Agent>();
  private tasks = new Map<string, Task>();
  private approvals = new Map<string, Approval>();
  private mission: Mission | null = null;
  private resources: Resources = { tokensUsed: 0, tokenBudget: null, costUsd: 0, costBudgetUsd: null };
  private log: LogLine[] = [];
  source: string;
  missionControlUrl: string | null = null;
  readonly now: () => number;

  constructor(source: string, now: () => number = Date.now) {
    super();
    this.source = source;
    this.now = now;
    for (const r of ROSTER) {
      this.agents.set(r.id, {
        ...r,
        state: "idle",
        location: "command_centre",
        taskId: null,
        taskTitle: null,
        detail: null,
        progress: null,
        updatedAt: now(),
      });
    }
  }

  snapshot(): WorldSnapshot {
    return {
      contract: CONTRACT_VERSION,
      source: this.source,
      mission: this.mission,
      agents: [...this.agents.values()],
      tasks: [...this.tasks.values()],
      approvals: [...this.approvals.values()],
      resources: this.resources,
      log: this.log,
      links: { missionControl: this.missionControlUrl },
    };
  }

  get currentSeq(): number {
    return this.seq;
  }

  getAgent(id: string): Agent | undefined {
    return this.agents.get(id);
  }

  getMission(): Mission | null {
    return this.mission;
  }

  getTask(id: string): Task | undefined {
    return this.tasks.get(id);
  }

  getApproval(id: string): Approval | undefined {
    return this.approvals.get(id);
  }

  private emitEvent(event: ServerEvent): void {
    const msg = { ...event, seq: ++this.seq } as ServerMessage;
    this.emit("message", msg);
  }

  setAgent(id: string, u: AgentUpdate): Agent {
    const a = this.agents.get(id);
    if (!a) throw new Error(`unknown agent ${id}`);
    const next: Agent = {
      ...a,
      state: u.state,
      location: locationFor(u.state, a.role, u.building, a.location),
      taskId: u.taskId !== undefined ? u.taskId : a.taskId,
      taskTitle: u.taskTitle !== undefined ? u.taskTitle : a.taskTitle,
      detail: u.detail !== undefined ? u.detail : a.detail,
      progress: u.progress !== undefined ? u.progress : u.state === "working" ? a.progress : null,
      updatedAt: this.now(),
    };
    if (u.state === "idle") {
      next.taskId = null;
      next.taskTitle = null;
      next.detail = null;
      next.progress = null;
    }
    this.agents.set(id, next);
    this.emitEvent({ type: "agent.state", agent: next });
    return next;
  }

  upsertTask(t: Partial<Task> & { id: string }): Task {
    const prev = this.tasks.get(t.id);
    const ts = this.now();
    const next: Task = {
      missionId: this.mission?.id ?? "",
      title: "",
      agentId: null,
      status: "queued",
      result: null,
      createdAt: ts,
      ...prev,
      ...t,
      updatedAt: ts,
    };
    this.tasks.set(t.id, next);
    this.emitEvent({ type: "task.upsert", task: next });
    return next;
  }

  startMission(id: string, title: string): Mission {
    this.tasks.clear();
    this.approvals.clear();
    this.mission = { id, title, status: "planning", result: null, startedAt: this.now(), endedAt: null };
    this.emitEvent({ type: "mission.upsert", mission: this.mission });
    this.setResources({ tokensUsed: 0, costUsd: 0 });
    return this.mission;
  }

  updateMission(patch: Partial<Mission>): Mission | null {
    if (!this.mission) return null;
    const done = patch.status === "completed" || patch.status === "failed" || patch.status === "cancelled";
    this.mission = { ...this.mission, ...patch, endedAt: done ? this.now() : this.mission.endedAt };
    this.emitEvent({ type: "mission.upsert", mission: this.mission });
    return this.mission;
  }

  upsertApproval(a: Partial<Approval> & { id: string }): Approval {
    const prev = this.approvals.get(a.id);
    const next: Approval = {
      missionId: this.mission?.id ?? null,
      agentId: null,
      tool: "",
      summary: "",
      status: "pending",
      createdAt: this.now(),
      ...prev,
      ...a,
    };
    this.approvals.set(a.id, next);
    this.emitEvent({ type: "approval.upsert", approval: next });
    return next;
  }

  setResources(patch: Partial<Resources>): void {
    this.resources = { ...this.resources, ...patch };
    this.emitEvent({ type: "resource.update", resources: this.resources });
  }

  addTokens(tokens: number, costUsd = 0): void {
    this.setResources({ tokensUsed: this.resources.tokensUsed + tokens, costUsd: this.resources.costUsd + costUsd });
  }

  logLine(text: string, level: LogLine["level"] = "info", agentId: string | null = null): void {
    const line: LogLine = { ts: this.now(), level, text, agentId };
    this.log.push(line);
    if (this.log.length > LOG_LIMIT) this.log.splice(0, this.log.length - LOG_LIMIT);
    this.emitEvent({ type: "log", line });
  }

  resetAgents(): void {
    for (const id of this.agents.keys()) this.setAgent(id, { state: "idle" });
  }
}
