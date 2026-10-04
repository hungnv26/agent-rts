"""Agent RTS plugin for Hermes Synapse.

Mounted into the backend at backend/agentrts/plugin.py (see infra/hermes.override.yml).
Hermes core calls these hooks at startup; nothing in the vendor tree is modified.

Seeds the sub-agents the game shows besides Hermes' own research and code agents:
Scout, Data Analyst ("insights"), Writer and Reviewer.
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


SCOUT_PROMPT = (
    "You are the Scout. Run one or two quick web searches for the latest news, announcements "
    "and dates related to the request, and return 4-6 dated headlines with their sources."
)

WRITER_PROMPT = (
    "You are the Writer. Using only the findings provided by the other agents, draft a clear "
    "report in Markdown: a one-line summary, key findings as bullets with sources, and a short "
    "conclusion. Do not invent facts."
)


def get_migration_agents():
    # (id, name, system_prompt, agent_type, parent_id, skills, x, y)
    return [
        ("scout", "Scout", SCOUT_PROMPT, "agent", "jarvis", "web_search", 450, 820),
        ("insights", "Data Analyst", INSIGHTS_PROMPT, "agent", "jarvis", REASONING_ONLY, 450, 940),
        ("writer", "Writer", WRITER_PROMPT, "agent", "jarvis", REASONING_ONLY, 450, 1000),
        ("reviewer", "Reviewer", REVIEWER_PROMPT, "agent", "jarvis", REASONING_ONLY, 450, 1060),
    ]
