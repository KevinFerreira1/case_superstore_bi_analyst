from __future__ import annotations

from datetime import datetime, timedelta

from airflow.decorators import dag
from airflow.operators.trigger_dagrun import TriggerDagRunOperator

DEFAULT_ARGS = {
    "owner": "Kevin Ferreira",
    "depends_on_past": False,
    "email_on_failure": False,
    "email_on_retry": False,
    "retries": 2,
    "retry_delay": timedelta(minutes=2),
}

@dag(
    dag_id="orchestrate_superstore",
    default_args=DEFAULT_ARGS,
    description="Daily orchestration of SuperStore pipeline",
    schedule="@daily",
    start_date=datetime(2026, 6, 8),
    catchup=False,
    tags=["superstore", "orchestration"],
)
def orchestrate_superstore():

    trigger_xlsx = TriggerDagRunOperator(
        task_id="trigger_xlsx_to_parquet",
        trigger_dag_id="xlsx_to_parquet_s3",
        wait_for_completion=True,
    )

    trigger_trusted = TriggerDagRunOperator(
        task_id="trigger_materialize_trusted",
        trigger_dag_id="materialize_trusted",
        wait_for_completion=True,
    )

    trigger_refined = TriggerDagRunOperator(
        task_id="trigger_materialize_refined",
        trigger_dag_id="materialize_refined",
        wait_for_completion=True,
    )

    trigger_xlsx >> trigger_trusted >> trigger_refined

orchestrate_superstore()
