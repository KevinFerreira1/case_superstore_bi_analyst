from __future__ import annotations

import time
from datetime import datetime, timedelta

from airflow.decorators import dag, task
from airflow.models import Variable

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
# Each dict represents one view → table materialization.
# Add new entries here when more views need to be materialized.
# ---------------------------------------------------------------------------

S3_BUCKET = Variable.get("s3_superstore_bucket")
ATHENA_DATABASE = "superstore_db"
ATHENA_WORKGROUP = "primary"
AWS_REGION = "us-east-2"
ATHENA_OUTPUT_LOCATION = f"s3://{S3_BUCKET}/athena-query-results/"

# Dimensions — no dependency between them; all read from trusted_orders
DIMENSION_MATERIALIZATIONS: list[dict[str, str]] = [
    {
        "view": "superstore_db.vw_dim_date",
        "table": "superstore_db.dim_date",
        "s3_path": "refined/dim_date",
    },
    {
        "view": "superstore_db.vw_dim_customer",
        "table": "superstore_db.dim_customer",
        "s3_path": "refined/dim_customer",
    },
    {
        "view": "superstore_db.vw_dim_product",
        "table": "superstore_db.dim_product",
        "s3_path": "refined/dim_product",
    },
    {
        "view": "superstore_db.vw_dim_geography",
        "table": "superstore_db.dim_geography",
        "s3_path": "refined/dim_geography",
    },
    {
        "view": "superstore_db.vw_dim_shipping",
        "table": "superstore_db.dim_shipping",
        "s3_path": "refined/dim_shipping",
    },
]

# Fact — must run AFTER all dimensions are materialized
FACT_MATERIALIZATIONS: list[dict[str, str]] = [
    {
        "view": "superstore_db.vw_fact_orders",
        "table": "superstore_db.fact_orders",
        "s3_path": "refined/fact_orders",
    },
]

DEFAULT_ARGS = {
    "owner": "Kevin Ferreira",
    "depends_on_past": False,
    "email_on_failure": False,
    "email_on_retry": False,
    "retries": 2,
    "retry_delay": timedelta(minutes=2),
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _get_athena_client():
    """Creates an Athena client using the Airflow aws_default connection."""
    from airflow.providers.amazon.aws.hooks.base_aws import AwsBaseHook

    hook = AwsBaseHook(aws_conn_id="aws_default", client_type="athena")
    return hook.get_session(region_name=AWS_REGION).client("athena")


def _wait_for_query(athena_client, execution_id: str, max_wait: int = 300) -> str:
    """Polls Athena until the query finishes. Returns final state."""
    elapsed = 0
    while elapsed < max_wait:
        resp = athena_client.get_query_execution(QueryExecutionId=execution_id)
        state = resp["QueryExecution"]["Status"]["State"]
        if state in ("SUCCEEDED", "FAILED", "CANCELLED"):
            if state != "SUCCEEDED":
                reason = resp["QueryExecution"]["Status"].get("StateChangeReason", "")
                raise RuntimeError(f"Athena query {state}: {reason}")
            return state
        time.sleep(5)
        elapsed += 5
    raise TimeoutError(f"Athena query did not finish within {max_wait}s")


# ---------------------------------------------------------------------------
# Reusable task builders
# ---------------------------------------------------------------------------

def _build_materialization_tasks(mat: dict[str, str]):
    """Builds the clean → drop → create chain for a single materialization."""
    view = mat["view"]
    table = mat["table"]
    s3_path = mat["s3_path"]
    task_suffix = table.split(".")[-1]

    @task(task_id=f"clean_s3__{task_suffix}")
    def clean_s3(s3_path: str, **kwargs) -> dict:
        """Delete all existing files in the S3 target path."""
        from airflow.providers.amazon.aws.hooks.s3 import S3Hook

        hook = S3Hook(aws_conn_id="aws_default")
        bucket = S3_BUCKET
        prefix = f"{s3_path}/"

        keys = hook.list_keys(bucket_name=bucket, prefix=prefix)

        if keys:
            hook.delete_objects(bucket=bucket, keys=keys)
            return {"deleted_keys": len(keys), "path": f"s3://{bucket}/{prefix}"}

        return {"deleted_keys": 0, "path": f"s3://{bucket}/{prefix}"}

    @task(task_id=f"drop_table__{task_suffix}")
    def drop_table(table: str, clean_result: dict, **kwargs) -> str:
        """Drop the existing Athena table if it exists."""
        client = _get_athena_client()
        sql = f"DROP TABLE IF EXISTS {table};"

        resp = client.start_query_execution(
            QueryString=sql,
            QueryExecutionContext={"Database": ATHENA_DATABASE},
            ResultConfiguration={"OutputLocation": ATHENA_OUTPUT_LOCATION},
            WorkGroup=ATHENA_WORKGROUP,
        )

        _wait_for_query(client, resp["QueryExecutionId"])
        return f"Dropped {table}"

    @task(task_id=f"create_table__{task_suffix}")
    def create_table(view: str, table: str, s3_path: str, drop_result: str, **kwargs) -> dict:
        """Create the table from the view using CTAS (Parquet + Snappy)."""
        client = _get_athena_client()
        bucket = S3_BUCKET

        sql = f"""
            CREATE TABLE {table}
            WITH (
                format = 'PARQUET',
                parquet_compression = 'SNAPPY',
                external_location = 's3://{bucket}/{s3_path}/'
            )
            AS SELECT * FROM {view};
        """

        resp = client.start_query_execution(
            QueryString=sql,
            QueryExecutionContext={"Database": ATHENA_DATABASE},
            ResultConfiguration={"OutputLocation": ATHENA_OUTPUT_LOCATION},
            WorkGroup=ATHENA_WORKGROUP,
        )

        _wait_for_query(client, resp["QueryExecutionId"])

        return {
            "table": table,
            "source_view": view,
            "s3_location": f"s3://{bucket}/{s3_path}/",
            "status": "SUCCEEDED",
        }

    # Chain: clean S3 → drop table → create table (CTAS)
    s3_result = clean_s3(s3_path=s3_path)
    drop_result = drop_table(table=table, clean_result=s3_result)
    return create_table(view=view, table=table, s3_path=s3_path, drop_result=drop_result)


# ---------------------------------------------------------------------------
# DAG
# ---------------------------------------------------------------------------

@dag(
    dag_id="materialize_refined",
    default_args=DEFAULT_ARGS,
    description="Materializes Athena views into physical tables in the trusted S3 layer",
    schedule=None,  # Trigger-ready: will be called by an orchestration DAG
    start_date=datetime(2026, 6, 8),
    catchup=False,
    tags=["superstore", "refined", "materialization", "trigger-ready"],
)
def materialize_refined():

    # ── Phase 1: Materialize all dimensions in parallel ──
    dimension_results = []
    for mat in DIMENSION_MATERIALIZATIONS:
        result = _build_materialization_tasks(mat)
        dimension_results.append(result)

    # ── Phase 2: Materialize fact table AFTER all dimensions ──
    for mat in FACT_MATERIALIZATIONS:
        fact_result = _build_materialization_tasks(mat)
        # Set dependency: fact waits for ALL dimensions to finish
        for dim_result in dimension_results:
            dim_result >> fact_result


materialize_refined()
