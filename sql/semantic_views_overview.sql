-- ============================================================================
-- Semantic views overview: the four governed views behind the object
-- explainer agent. One view per metadata domain, deliberately small and
-- single-purpose; the Cortex Agent owns the cross-domain reasoning.
--
-- Underlying metadata tables are sketched in each section so the views are
-- self-explanatory. All names are sample/synthetic.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Transformation metadata
--    Sources, build logic and tests for every object.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE VIEW GOVERNANCE_DB.META.TRANSFORMATION_OBJECTS AS
SELECT
    object_name,
    object_type,               -- TABLE / VIEW / MODEL
    database_name,
    schema_name,
    owner_team,
    transform_tool,            -- e.g. DBT, MATILLION
    source_object_name,        -- one row per upstream source
    test_name                  -- data-quality test attached to the object
FROM GOVERNANCE_DB.META.TRANSFORMATION_METADATA_SAMPLE;

CREATE OR REPLACE SEMANTIC VIEW GOVERNANCE_DB.SEMANTIC.TRANSFORMATION_SV
    TABLES (
        objects AS GOVERNANCE_DB.META.TRANSFORMATION_OBJECTS
    )
    FACTS (
        objects.source_count AS COUNT(DISTINCT source_object_name)
    )
    DIMENSIONS (
        objects.object_name    AS object_name    WITH SYNONYMS = ('model', 'table', 'view'),
        objects.object_type    AS object_type,
        objects.owner_team     AS owner_team     WITH SYNONYMS = ('owner', 'team'),
        objects.transform_tool AS transform_tool WITH SYNONYMS = ('built with', 'etl tool'),
        objects.source_object_name AS source_object_name WITH SYNONYMS = ('upstream', 'source'),
        objects.test_name      AS test_name      WITH SYNONYMS = ('data quality test')
    )
    COMMENT = 'Sources, build logic and tests for data objects.';

-- ----------------------------------------------------------------------------
-- 2. Orchestration metadata
--    The job that builds/refreshes each object, its schedule and run history.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE VIEW GOVERNANCE_DB.META.ORCHESTRATION_JOBS AS
SELECT
    object_name,
    job_name,
    job_owner_team,
    schedule_description,      -- e.g. 'DAILY 02:00 UTC'
    run_started_at,
    run_status                 -- SUCCESS / FAILED / RUNNING
FROM GOVERNANCE_DB.META.ORCHESTRATION_METADATA_SAMPLE;

CREATE OR REPLACE SEMANTIC VIEW GOVERNANCE_DB.SEMANTIC.ORCHESTRATION_SV
    TABLES (
        jobs AS GOVERNANCE_DB.META.ORCHESTRATION_JOBS
    )
    FACTS (
        jobs.run_count        AS COUNT(*),
        jobs.failed_run_count AS COUNT_IF(run_status = 'FAILED')
    )
    DIMENSIONS (
        jobs.object_name          AS object_name,
        jobs.job_name             AS job_name        WITH SYNONYMS = ('owning job', 'pipeline'),
        jobs.job_owner_team       AS job_owner_team  WITH SYNONYMS = ('job owner'),
        jobs.schedule_description AS schedule        WITH SYNONYMS = ('refresh schedule'),
        jobs.run_status           AS run_status,
        jobs.run_started_at       AS run_started_at  WITH SYNONYMS = ('last run')
    )
    COMMENT = 'Owning job, schedule and run history per data object.';

-- ----------------------------------------------------------------------------
-- 3. Warehouse metadata
--    Physical profile: size, rows, clustering, freshness.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE VIEW GOVERNANCE_DB.META.WAREHOUSE_OBJECTS AS
SELECT
    object_name,
    row_count,
    size_bytes,
    clustering_depth,
    last_refreshed_at
FROM GOVERNANCE_DB.META.WAREHOUSE_METADATA_SAMPLE;

CREATE OR REPLACE SEMANTIC VIEW GOVERNANCE_DB.SEMANTIC.WAREHOUSE_SV
    TABLES (
        objects AS GOVERNANCE_DB.META.WAREHOUSE_OBJECTS
    )
    FACTS (
        objects.row_count AS row_count,
        objects.size_mb   AS size_bytes / 1048576.0
    )
    DIMENSIONS (
        objects.object_name       AS object_name,
        objects.clustering_depth  AS clustering_depth WITH SYNONYMS = ('clustering'),
        objects.last_refreshed_at AS last_refreshed_at WITH SYNONYMS = ('freshness', 'last refresh')
    )
    COMMENT = 'Physical profile of data objects in the warehouse.';

-- ----------------------------------------------------------------------------
-- 4. BI-layer metadata
--    Downstream consumers: dashboards and reports that read each object.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE VIEW GOVERNANCE_DB.META.BI_CONSUMERS AS
SELECT
    object_name,
    dashboard_name,
    dashboard_owner_team
FROM GOVERNANCE_DB.META.BI_METADATA_SAMPLE;

CREATE OR REPLACE SEMANTIC VIEW GOVERNANCE_DB.SEMANTIC.BI_LAYER_SV
    TABLES (
        consumers AS GOVERNANCE_DB.META.BI_CONSUMERS
    )
    FACTS (
        consumers.dashboard_count AS COUNT(DISTINCT dashboard_name)
    )
    DIMENSIONS (
        consumers.object_name          AS object_name,
        consumers.dashboard_name       AS dashboard_name WITH SYNONYMS = ('downstream dashboard', 'report'),
        consumers.dashboard_owner_team AS dashboard_owner_team WITH SYNONYMS = ('dashboard owner')
    )
    COMMENT = 'Dashboards and reports that read each data object.';
