Changelog

All notable changes to this project will be documented in this file.

[1.03.1] - 2026-06-11

Added
- Add dags/dag_orchestrate_superstore.py 

Changed
- Add concated region name in vr trusted view for region column

[1.02.1] - 2026-06-11

Added
- Added dags/dag_materialize_refined.py to orchestrate refined layer materialization
- Added refined layer dimensional and fact views under sql/views/superstore/ (vw_dim_customer.sql, vw_dim_date.sql, vw_dim_geography.sql, vw_dim_product.sql, vw_dim_shipping.sql, vw_fact_orders.sql)
- Added SQL validations for the refined layer under sql/validations/refined/
- Added Power BI dashboard SVG icons under powerbi/icons/ and created case.txt

Changed
- Reorganized trusted layer validations by moving them to sql/validations/trusted/
- Updated sql/views/superstore/vw_trusted_orders.sql

[1.01.1] - 2026-06-10

Added

Added dags/dag_materialize_trusted.py, sql/validations/validate_category.sql, sql/validations/validate_customer.sql, sql/validations/validate_negative_returns.sql, sql/validations/validate_nulls.sql, sql/validations/validate_product_name.sql, sql/validations/validate_valid_subcategory.sql, sql/views/superstore/vw_trusted_orders.sql
Hotfix on dag_xlsx_to_parquet_s3.py, changed bucket schema

[1.00.0] - 2026-06-08

Added

Added dag_xlsx_to_parquet_s3.py, docker-compose.yml, Dockerfile, README.md, requirements.txt, .gitignore
Added CHANGELOG.md file