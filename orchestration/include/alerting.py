"""Failure alerting shared by all DAGs.

Always logs a structured error (visible in the Airflow UI / task logs, works
with zero setup). Also posts to Slack if SLACK_WEBHOOK_URL is set in the
environment — unset by default, so this is a no-op until someone adds that
one secret to orchestration/.env.
"""

import logging
import os

logger = logging.getLogger(__name__)


def notify_failure(context):
    dag_id = context["dag"].dag_id
    task_id = context["task_instance"].task_id
    run_id = context["run_id"]
    exception = context.get("exception")

    message = f"[ALERT] {dag_id}.{task_id} failed (run_id={run_id}): {exception}"
    logger.error(message)

    webhook_url = os.environ.get("SLACK_WEBHOOK_URL")
    if not webhook_url:
        return

    import requests

    requests.post(webhook_url, json={"text": message}, timeout=10)
