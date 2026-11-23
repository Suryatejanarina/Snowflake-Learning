/* =====================================================================
   Snowflake: COPY INTO, COPY FILES and Storage Integration
   - COPY INTO <table>    : load files from a stage into a table
   - COPY INTO <location> : unload table data to files in a stage
   - COPY FILES           : copy files from one stage to another
   - STORAGE INTEGRATION  : secure connection to cloud storage
   ===================================================================== */

   USE DATABASE LEARNING;
   USE SCHEMA LEARNING_SCHEMA;


/* =====================================================================
   COPY INTO - OVERVIEW
   - Snowflake's bulk loading command.
   - Loads files from a stage into a table using a file format
     and a running warehouse.
   - Skips files that were already loaded (load history is kept
     for 64 days) unless FORCE = TRUE is used.
   - Can also unload table data to a stage.
   ===================================================================== */


/* =====================================================================
   1. LOAD DATA: STAGE -> TABLE
   ===================================================================== */

-- Step 1: Create a file format to use with the stage
CREATE OR REPLACE FILE FORMAT INGEST_DATA
    TYPE = CSV
    SKIP_HEADER = 1
    FIELD_DELIMITER = ','
    RECORD_DELIMITER = '\n'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE;   -- do not fail if a row has fewer/more columns

-- Step 2: Create a named internal stage to hold the files
CREATE OR REPLACE STAGE EMPLOYEE_STAGE
    FILE_FORMAT = INGEST_DATA;

-- Step 3: Upload your files to the stage using the Snowsight UI
--         or the PUT command in SnowSQL (PUT does not work in Snowsight worksheets)
--         Example: PUT file://C:\data\employees.csv @EMPLOYEE_STAGE;

-- Step 4: Verify the files and data in the stage
LIST @EMPLOYEE_STAGE;
SELECT $1, $2, $3, $4, $5 FROM @EMPLOYEE_STAGE;   -- $1..$5 = file columns by position

-- Step 5: Create the target table
CREATE OR REPLACE TABLE EMPLOYEES (
    EmpId        INT,
    EmpName      VARCHAR(40),
    Organization VARCHAR(40),
    JoinDate     DATE,
    Country      VARCHAR(30)
);

-- Step 6: Validate first (checks for errors, does NOT load any data)
-- VALIDATION_MODE options: RETURN_ERRORS, RETURN_ALL_ERRORS, RETURN_<n>_ROWS
COPY INTO EMPLOYEES
FROM @EMPLOYEE_STAGE
VALIDATION_MODE = RETURN_ALL_ERRORS;

-- Step 7: Load the data from the stage into the table
-- ON_ERROR decides what happens when a record has an error:
--   ABORT_STATEMENT : stop the whole load (default for COPY INTO)
--   CONTINUE        : skip the bad records and load the rest
--   SKIP_FILE       : skip the entire file that has errors
COPY INTO EMPLOYEES
FROM @EMPLOYEE_STAGE
ON_ERROR = ABORT_STATEMENT;

-- Step 8: Verify the data in the table
SELECT EmpId, EmpName, Organization, JoinDate, Country
FROM EMPLOYEES
LIMIT 10;


/* =====================================================================
   2. OTHER COPY INTO (LOAD) OPTIONS
   ===================================================================== */

-- FORCE = TRUE
--   Reloads files even if they were already loaded.
--   Rows are APPENDED, so this creates duplicates. It does not replace data.
-- COPY INTO EMPLOYEES FROM @EMPLOYEE_STAGE FORCE = TRUE;

-- PURGE = TRUE
--   Deletes the files from the stage right after a successful load.
-- COPY INTO EMPLOYEES FROM @EMPLOYEE_STAGE PURGE = TRUE;

-- PATTERN = '<regex>'
--   Loads only the files whose names match the pattern.
-- COPY INTO EMPLOYEES FROM @EMPLOYEE_STAGE PATTERN = '.*\.csv';

-- MATCH_BY_COLUMN_NAME = CASE_SENSITIVE | CASE_INSENSITIVE | NONE
--   Loads data by matching file column names to table column names
--   (instead of by position).
--   Works for JSON, Parquet, Avro, ORC. For CSV it needs PARSE_HEADER = TRUE
--   in the file format.

-- INCLUDE_METADATA = (<column> = METADATA$FILENAME)
--   Adds file metadata (for example the file name) into a table column.
--   Must be used together with MATCH_BY_COLUMN_NAME.


/* =====================================================================
   3. UNLOAD DATA: TABLE -> STAGE
   - Supported formats: CSV (including TSV), JSON, Parquet.
   - Files are compressed (gzip) by default.
   ===================================================================== */

-- Remove existing files so the stage is clean (deletes ALL files in the stage)
REMOVE @EMPLOYEE_STAGE;
LIST @EMPLOYEE_STAGE;

-- Unload the table into the stage
-- 'EMPLOYEEDATA' is used as the file name prefix
-- HEADER = TRUE is needed because the file format has SKIP_HEADER = 1;
-- without a header, the first data row would be skipped when queried
COPY INTO @EMPLOYEE_STAGE/EMPLOYEEDATA
FROM EMPLOYEES
HEADER = TRUE;

LIST @EMPLOYEE_STAGE;
SELECT $1, $2, $3, $4, $5 FROM @EMPLOYEE_STAGE;

/* ---------------------------------------------------------------------
   OTHER UNLOAD OPTIONS
   VALIDATION_MODE = RETURN_ROWS   : returns the rows that would be unloaded,
                                     without unloading (check before unloading)
   HEADER = TRUE                   : adds a header row to the file
   SINGLE = TRUE                   : writes all data into a single file
   MAX_FILE_SIZE = 16777216        : max size per file in bytes
                                     (default 16 MB, up to 5 GB = 5368709120)
   OVERWRITE = TRUE                : replaces files with the same name
   INCLUDE_QUERY_ID = TRUE         : adds the query ID to the file name
                                     (not supported with SINGLE = TRUE
                                      or OVERWRITE = TRUE)
   DETAILED_OUTPUT = TRUE          : returns details (path, size, row count)
                                     for each unloaded file
   --------------------------------------------------------------------- */


/* =====================================================================
   4. COPY FILES
   - Copies files from one stage to another stage.
   - Works with internal named stages and external named stages.
   - Files are copied as they are (no loading into a table).
   ===================================================================== */
CREATE OR REPLACE STAGE STAGEDATA
    FILE_FORMAT = INGEST_DATA;

COPY FILES INTO @STAGEDATA
FROM @EMPLOYEE_STAGE;

LIST @STAGEDATA;


/* =====================================================================
   5. STORAGE INTEGRATION
   - A Snowflake object that securely stores a reference to your cloud
     storage account, so you do not share actual cloud credentials.
   - Created once by an admin and reused by many external stages.
   - Requires ACCOUNTADMIN or the CREATE INTEGRATION privilege.

   NOTE: Sections 5 and 6 are a REFERENCE. They use placeholders (<...>)
   because no AWS S3 bucket is configured. Replace the placeholders
   with your own values before running.
   ===================================================================== */
USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE STORAGE INTEGRATION AWS_S3_INTEGRATION
    TYPE = EXTERNAL_STAGE
    STORAGE_PROVIDER = 'S3'
    ENABLED = TRUE
    STORAGE_AWS_ROLE_ARN = '<your_aws_iam_role_arn>'
    STORAGE_ALLOWED_LOCATIONS = ('s3://<your-bucket-name>/<folder>/');

-- Get the values needed to finish the AWS setup:
--   STORAGE_AWS_IAM_USER_ARN and STORAGE_AWS_EXTERNAL_ID
-- Add them to the trust policy of your AWS IAM role
DESC INTEGRATION AWS_S3_INTEGRATION;


/* =====================================================================
   6. LOAD DATA: EXTERNAL STAGE (S3) -> TABLE
   ===================================================================== */

-- Target table
CREATE OR REPLACE TABLE AWS_CUSTOMERLOAD (
    Cid          VARCHAR(10),
    Cname        VARCHAR(50),
    Address      VARCHAR(70),
    MobileNumber VARCHAR(12)
);

-- Recommended: external stage using the storage integration (no keys in code)
CREATE OR REPLACE STAGE S3_STAGE
    FILE_FORMAT = INGEST_DATA
    STORAGE_INTEGRATION = AWS_S3_INTEGRATION
    URL = 's3://<your-bucket-name>/<folder>/';

-- Alternative (not recommended): credentials directly on the stage
CREATE OR REPLACE STAGE AWS_STAGE
FILE_FORMAT = INGEST_DATA
URL = 's3://<your-bucket-name>/<folder>/'
CREDENTIALS = (AWS_KEY_ID = '<your_key>' AWS_SECRET_KEY = '<your_secret_key>');

-- Verify the files in the external stage
LIST @S3_STAGE;

-- Load from the external stage into the table
-- ON_ERROR = SKIP_FILE skips any file that has errors
COPY INTO AWS_CUSTOMERLOAD
FROM @S3_STAGE
ON_ERROR = SKIP_FILE;

-- Verify the data is loaded
SELECT * FROM AWS_CUSTOMERLOAD;
