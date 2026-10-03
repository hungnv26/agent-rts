"""Agent RTS plugin for Hermes Synapse.

Mounted into the backend at backend/agentrts/plugin.py (see infra/hermes.override.yml).
Hermes core calls these hooks at startup; nothing in the vendor tree is modified.

Seeds the Reviewer sub-agent the game expects. (Benching the seeded agents the game
does not use is done by the adapter at connect time: core's get_retired_agent_ids hook
deletes them and then immediately re-seeds them, so it cannot be used for that.)
"""

REVIEWER_PROMPT = (
    "You are the Reviewer. You check the work produced by the other agents for factual "
    "accuracy, missing points and clarity. You may use web_search to verify one or two key "
    "claims. Reply with a short verdict (APPROVE or NEEDS WORK), the issues you found, and "
    "the corrected final summary."
)


def get_migration_agents():
    # (id, name, system_prompt, agent_type, parent_id, skills, x, y)
    return [("reviewer", "Reviewer", REVIEWER_PROMPT, "agent", "jarvis", "web_search", 450, 1060)]
