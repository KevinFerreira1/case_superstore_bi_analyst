from __future__ import annotations

import os
from datetime import datetime, timedelta
import pandas as pd
from airflow.decorators import dag, task
from airflow.models import Variable

# Constants

XLSX_PATH = "/opt/airflow/data/SuperStore_ETL_Case_Base.xlsx"
LOCAL_TMP_DIR = "/tmp/superstore_parquet"
S3_BUCKET = Variable.get('s3_superstore_bucket')
S3_PREFIX = "raw"

SHEETS: dict[str, str] = {
    "Orders": "orders.parquet",
    "People": "people.parquet",
    "Returns": "returns.parquet",
}

DEFAULT_ARGS = {
    "owner": "Kevin Ferreira",
    "depends_on_past": False,
    "email_on_failure": False,
    "email_on_retry": False,
    "retries": 2,
    "retry_delay": timedelta(minutes=2),
}


# Helper
def _upload_to_s3(local_path: str, s3_key: str, bucket: str) -> None:
    from airflow.providers.amazon.aws.hooks.s3 import S3Hook

    hook = S3Hook(aws_conn_id="aws_default")
    hook.load_file(
        filename=local_path,
        key=s3_key,
        bucket_name=bucket,
        replace=True,
    )

# DAG
@dag(
    dag_id="xlsx_to_parquet_s3",
    default_args=DEFAULT_ARGS,
    description="Convert SuperStore XLSX tabs to Parquet and upload to S3",
    schedule=None, 
    start_date=datetime(2026, 6, 8),
    catchup=False,
    tags=["superstore", "ingestion", "s3"],
)
def xlsx_to_parquet_s3():

    @task()
    def extract_and_upload(sheet_name: str, parquet_filename: str) -> dict:
        bucket = S3_BUCKET
        prefix = S3_PREFIX

        # 1. Read the Excel sheet
        df = pd.read_excel(XLSX_PATH, sheet_name=sheet_name, engine="openpyxl")

        # 1b. Raw layer: keep all data as-is (strings)
        df = df.astype(str)

        # 2. Write local Parquet file
        subfolder = sheet_name.lower()  
        local_dir = os.path.join(LOCAL_TMP_DIR, subfolder)
        os.makedirs(local_dir, exist_ok=True)
        local_path = os.path.join(local_dir, parquet_filename)
        df.to_parquet(local_path, engine="pyarrow", index=False)

        # 3. Upload to S3
        s3_key = f"{prefix}/{subfolder}/{parquet_filename}"
        _upload_to_s3(local_path, s3_key, bucket)

        # 4. Cleanup temp file
        os.remove(local_path)

        return {
            "sheet": sheet_name,
            "rows": len(df),
            "columns": len(df.columns),
            "s3_key": f"s3://{bucket}/{s3_key}",
        }

    for sheet, filename in SHEETS.items():
        extract_and_upload(sheet_name=sheet, parquet_filename=filename)


xlsx_to_parquet_s3()