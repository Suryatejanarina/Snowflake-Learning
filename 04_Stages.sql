/* =====================================================================
   Snowflake: Stages
   Covers: User stage, Table stage, Named internal stage, External stage
   ===================================================================== */

USE DATABASE Learning;
USE SCHEMA Learning_Schema;


/* =====================================================================
   STAGE OVERVIEW
   - A stage is a location where data files are stored before being
     loaded into Snowflake tables (or unloaded from tables).
   - Two types: Internal stages and External stages.
   - Internal stages are of three kinds:
       1. User stage          -> @~
       2. Table stage         -> @%<table_name>
       3. Named internal stage -> @<stage_name>
   ===================================================================== */


/* =====================================================================
   1. USER STAGE  (@~)
   - Created automatically for every user.
   - No storage limit.
   - Private: no one else can see the files.
   - Cannot be altered or dropped.
   - Best for: files accessed by a single user but loaded into
     multiple tables.
   ===================================================================== */
LIST @~;    -- user stage is referenced using @~


/* =====================================================================
   2. TABLE STAGE  (@%<table_name>)
   - Created automatically for every table.
   - No storage limit.
   - Accessible only to users with privileges on the table.
   - Cannot be altered or dropped on its own (removed with the table).
   - Does not support transforming data while loading.
   - Best for: loading files into a single table that multiple users
     need access to.
   ===================================================================== */
LIST @%Employee_Details;    -- table stage is referenced using @%<table_name>


/* =====================================================================
   3. NAMED INTERNAL STAGE  (@<stage_name>)
   - Created manually by the user using CREATE STAGE (no URL parameter).
   - Files are stored inside Snowflake in Snowflake-managed storage.
   - No cloud credentials needed.
   - Can be shared with other roles using GRANT READ / WRITE.
   - Supports a default file format and copy options.
   - Files are uploaded with PUT (SnowSQL) or the Snowsight UI.
   - Best for: shared, reusable loading locations inside Snowflake.
   ===================================================================== */

-- Step 1: Create a file format describing the files
CREATE OR REPLACE FILE FORMAT CSV_FORMAT
    TYPE = 'CSV'
    SKIP_HEADER = 1
    FIELD_DELIMITER = ','
    RECORD_DELIMITER = '\n';

-- Step 2: Create the named internal stage using the file format
CREATE OR REPLACE STAGE CSV_STAGE
    FILE_FORMAT = CSV_FORMAT
    COMMENT = 'Named internal stage for CSV files';

-- Step 3: Verify the stage
SHOW STAGES;
DESC STAGE CSV_STAGE;

-- Step 4: List files in the stage (empty until files are uploaded)
LIST @CSV_STAGE;


/* =====================================================================
   4. EXTERNAL STAGE
   - Points to files stored in your own cloud storage
     (AWS S3, Azure Blob Storage, Google Cloud Storage).
   - Data stays outside Snowflake; only the stage definition is stored.
   - Requires a URL and a storage integration (or credentials).
   - You manage storage, access and cost on the cloud side.
   - PUT cannot be used to upload; place files using cloud tools.
   - Best for: existing data lakes and large data volumes.

   ===================================================================== */
CREATE OR REPLACE STAGE my_external_stage
    URL = 's3://<your-bucket-name>/<folder>/'              -- replace with your S3 URL
    STORAGE_INTEGRATION = <your_storage_integration>       -- replace with your integration name
    FILE_FORMAT = CSV_FORMAT;                              -- reuse the file format created above

-- List files in the external stage (works only with a real bucket)
LIST @my_external_stage;
