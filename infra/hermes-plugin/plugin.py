"""Agent RTS plugin for Hermes Synapse.

Mounted into the backend at backend/agentrts/plugin.py (see infra/hermes.override.yml).
Hermes core calls these hooks at startup; nothing in the vendor tree is modified.

Seeds the Reviewer and the Data Analyst ("insights") sub-agents the game expects.
(Benching the seeded agents the game
does not use is done by the adapter at connect time: core's get_retired_agent_ids hook
deletes them and then immediately re-seeds them, so it cannot be used for that.)
"""

REVIEWER_PROMPT = (
    "You are the Reviewer. You check the work produced by the other agents for factual "
    "accuracy, internal consistency, missing points and clarity, using only the material "
    "provided. Reply with a short verdict (APPROVE or NEEDS WORK), the issues you found, and "
    "the corrected final summary."
)

# An empty skills string gives a Hermes sub-agent every "safe" tool. An unknown skill name
# gives it only its memory tools, i.e. a single reasoning call over the context it is handed.
# With small local models, extra tool rounds push the final call past Hermes' 45 s limit.
REASONING_ONLY = "reasoning"


# Hermes' built-in "analyst" writes and runs plotting code in a self-correcting loop,
# which is too slow for small local models (45 s per-call limit). Extracting trends from
# gathered material needs no code, so the game's Analyst is a plain tool-loop agent.
INSIGHTS_PROMPT = (
    "You are the Data Analyst. From the material gathered by the other agents, extract the "
    "key facts, numbers and trends. Be concrete: quote figures with their source and year, "
    "flag anything uncertain, and finish with 3-6 bullet points of key findings."
)


def get_migration_agents():
    # (id, name, system_prompt, agent_type, parent_id, skills, x, y)
    return [
        ("insights", "Data Analyst", INSIGHTS_PROMPT, "agent", "jarvis", REASONING_ONLY, 450, 940),
        ("reviewer", "Reviewer", REVIEWER_PROMPT, "agent", "jarvis", REASONING_ONLY, 450, 1060),
    ]
