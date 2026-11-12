# Multi-View Cortex Agent

**One question, four semantic views, a complete answer: explain any data object end to end — its sources, its logic, its downstream dashboards, and the job that owns it.**

## Overview

This project configures a Snowflake Cortex Agent that reasons across several semantic views at once — transformation metadata, orchestration metadata, warehouse metadata and BI-layer metadata — to explain any data object end to end. Instead of a person manually stitching together a dbt model, the job that runs it, the warehouse it lands in and the dashboards that read it, the agent plans which views to query, asks each one for its part of the story, and composes a single coherent explanation.

## Problem

"Tell me everything about this table" is one of the most common questions in a large data platform, and one of the slowest to answer by hand:

- **Sources and logic** live in transformation metadata (dbt / ELT tooling).
- **The owning job and its schedule** live in orchestration metadata.
- **Physical details** — size, clustering, refresh pattern — live in warehouse metadata.
- **Downstream impact** — dashboards and reports — lives in BI-layer metadata.

Each system can answer its own slice. Nobody — and no single semantic view — can answer the whole question, so engineers burn hours on archaeology for audits, incidents and change-impact reviews.

## Architecture

```
 User: "Explain CUSTOMER_ACCOUNT end to end"
                    │
                    ▼
             Cortex Agent
        (orchestration instructions:
         plan → query views → compose)
        ┌───────┬───────────┬────────────┐
        ▼       ▼           ▼            ▼
  Transformation Orchestration  Warehouse    BI-layer
  semantic view  semantic view  semantic view semantic view
  (sources,      (owning job,   (size,        (downstream
   logic, tests)  schedule,      clustering,   dashboards,
                  last runs)     freshness)    owners)
        └───────┴───────────┴────────────┘
                    │
                    ▼
   End-to-end explanation: sources → logic → job →
   physical profile → downstream impact
```

- **Semantic views** — four governed views, one per metadata domain, each small and single-purpose (see `sql/semantic_views_overview.sql`).
- **Agent** — a Cortex Agent whose tools are the four views (via Cortex Analyst) and whose orchestration instructions define the explanation structure and the order views are consulted (see `agent/agent_config.yaml`).
- **Explainer client** — a Python entry point that submits an object name to the agent and prints the composed explanation (see `agent/explain_object.py`).

## Tech Stack

- Snowflake Cortex Agents and Cortex Analyst
- Snowflake semantic views
- Python 3.11+ (requests)
- SQL

## Key Components

| Component | Description |
|---|---|
| `agent/agent_config.yaml` | Agent definition: the four semantic-view tools, orchestration instructions, and response-shape rules for end-to-end explanations. |
| `agent/explain_object.py` | CLI client: takes an object name, calls the Cortex Agent, and prints the composed explanation. |
| `sql/semantic_views_overview.sql` | DDL sketches of the four underlying semantic views and the metadata each one exposes. |

## How It Works

1. The user names a data object — a table, view or model.
2. The agent plans the explanation using its orchestration instructions: identity first, then sources and transformation logic, then the owning job, then the physical profile, then downstream consumers.
3. It queries each semantic view through Cortex Analyst, scoped to that object.
4. It composes the answers into one explanation with a fixed structure, so audits and impact reviews read the same way every time.
5. Anything a view cannot answer is stated as unknown rather than guessed — the instructions forbid the agent from inventing ownership or lineage.

## Outcomes

- End-to-end object explanations that previously took an engineer the better part of an hour are produced in one interaction.
- Change-impact and audit reviews start from a consistent, complete picture instead of four partial ones.
- Keeping each semantic view small and single-domain kept each one accurate; the agent, not the view, owns the cross-domain reasoning.

## Repo Structure

```
multi-view-cortex-agent/
├── README.md
├── agent/
│   ├── agent_config.yaml       # Cortex Agent definition and instructions
│   └── explain_object.py       # CLI: explain one object end to end
└── sql/
    └── semantic_views_overview.sql
```

## Note

Portfolio project based on production work in regulated financial services; code is a clean-room representative implementation with sample/synthetic metadata only.
