# Databricks notebook source
# MAGIC %md
# MAGIC # Infrastructure Setup
# MAGIC Creates Unity Catalog schemas and volumes for medallion architecture.
# MAGIC Run this once when setting up the project.

# COMMAND ----------

catalog = "PROJECT_CATALOG"

schemas = ["raw", "cleansed", "curated"]
volumes = [{"schema": "raw", "name": "batch_landing"}]

# COMMAND ----------

for schema in schemas:
    spark.sql(f"CREATE SCHEMA IF NOT EXISTS {catalog}.{schema}")
    print(f"Created schema: {catalog}.{schema}")

# COMMAND ----------

for vol in volumes:
    fqn = f"{catalog}.{vol['schema']}.{vol['name']}"
    spark.sql(f"CREATE VOLUME IF NOT EXISTS {fqn}")
    print(f"Created volume: {fqn}")

# COMMAND ----------

# Verify
for schema in schemas:
    tables = spark.sql(f"SHOW TABLES IN {catalog}.{schema}").collect()
    print(f"{catalog}.{schema}: {len(tables)} tables")
