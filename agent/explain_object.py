"""Explain a data object end to end via the multi-view Cortex Agent.

Submits an object name to the OBJECT_EXPLAINER_AGENT (defined in
agent_config.yaml). The agent plans across the transformation, orchestration,
warehouse and BI-layer semantic views and returns one composed explanation:
sources, logic, owning job, physical profile and downstream dashboards.

Configuration (environment variables):
  SNOWFLAKE_ACCOUNT_URL   e.g. https://<account>.snowflakecomputing.com
  SNOWFLAKE_JWT           a valid Snowflake session/JWT bearer token
  AGENT_NAME              agent to call (default OBJECT_EXPLAINER_AGENT)
  AGENT_DATABASE          database hosting the agent (default GOVERNANCE_DB)
  AGENT_SCHEMA            schema hosting the agent (default AGENTS)

Usage:
  python explain_object.py CUSTOMER_ACCOUNT
  python explain_object.py --database ANALYTICS --schema MARTS ORDERS
"""

from __future__ import annotations

import argparse
import os
import sys

import requests

DEFAULT_AGENT = "OBJECT_EXPLAINER_AGENT"


def build_question(obj: str, database: str | None, schema: str | None) -> str:
    qualified = ".".join(part for part in [database, schema, obj] if part)
    return f"Explain the data object {qualified} end to end."


def call_agent(
    account_url: str,
    jwt: str,
    agent_db: str,
    agent_schema: str,
    agent_name: str,
    question: str,
) -> str:
    """POST one message to the Cortex Agent and return its text answer."""
    endpoint = (
        account_url.rstrip("/")
        + f"/api/v2/databases/{agent_db}/schemas/{agent_schema}"
        + f"/agents/{agent_name}:run"
    )
    headers = {
        "Authorization": f"Bearer {jwt}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    payload = {
        "messages": [
            {"role": "user", "content": [{"type": "text", "text": question}]}
        ]
    }
    response = requests.post(endpoint, headers=headers, json=payload, timeout=300)
    response.raise_for_status()
    body = response.json()

    texts: list[str] = []
    for item in body.get("message", {}).get("content", []):
        if item.get("type") == "text":
            texts.append(item.get("text", ""))
    if not texts:
        raise RuntimeError("The agent returned no text answer.")
    return "\n".join(texts)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("object", help="Object name, e.g. CUSTOMER_ACCOUNT")
    parser.add_argument("--database", default=None, help="Object database")
    parser.add_argument("--schema", default=None, help="Object schema")
    args = parser.parse_args(argv)

    account_url = os.environ.get("SNOWFLAKE_ACCOUNT_URL")
    jwt = os.environ.get("SNOWFLAKE_JWT")
    if not account_url or not jwt:
        print(
            "ERROR: SNOWFLAKE_ACCOUNT_URL and SNOWFLAKE_JWT must be set.",
            file=sys.stderr,
        )
        return 2

    question = build_question(args.object, args.database, args.schema)
    answer = call_agent(
        account_url=account_url,
        jwt=jwt,
        agent_db=os.environ.get("AGENT_DATABASE", "GOVERNANCE_DB"),
        agent_schema=os.environ.get("AGENT_SCHEMA", "AGENTS"),
        agent_name=os.environ.get("AGENT_NAME", DEFAULT_AGENT),
        question=question,
    )
    print(answer)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
