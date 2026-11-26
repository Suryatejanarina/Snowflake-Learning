/* =====================================================================
   Snowflake: SNOWPIPE
   - Serverless, continuous data ingestion service.
   - Automatically loads data into a table as soon as new files
     arrive in a stage.
   - Uses Snowflake-managed compute, so no virtual warehouse is needed.
   - Billed for the compute used while loading, plus a small per-file charge.
   - Auto-ingest works only with EXTERNAL stages (S3, Azure, GCS).
     Internal stages load through the Snowpipe REST API.

   NOTE: This script is a REFERENCE. It uses placeholders (<...>)
   because no AWS S3 bucket is configured. Replace the placeholders
   with your own values before running.
   ===================================================================== */

USE DATABASE Learning;
USE SCHEMA Learning_schema;


/* =====================================================================
   STEP 1: FILE FORMAT
   Describes how Snowflake reads the incoming files.
   ===================================================================== */
CREATE OR REPLACE FILE FORMAT INGEST_DATA
    TYPE = CSV
    SKIP_HEADER = 1
    FIELD_DELIMITER = ','
    RECORD_DELIMITER = '\n'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE;   -- do not fail if a row has fewer/more columns


/* =====================================================================
   STEP 2: STORAGE INTEGRATION
   Securely connects Snowflake to your S3 bucket without sharing
   AWS keys. Created once by an admin and reused by many stages.
   ===================================================================== */
USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE STORAGE INTEGRATION AWS_S3_INTEGRATION
    TYPE = EXTERNAL_STAGE
    STORAGE_PROVIDER = 'S3'
    ENABLED = TRUE
    STORAGE_AWS_ROLE_ARN = '<your_aws_iam_role_arn>'
    STORAGE_ALLOWED_LOCATIONS = ('s3://<your-bucket-name>/<folder>/');

-- Get STORAGE_AWS_IAM_USER_ARN and STORAGE_AWS_EXTERNAL_ID
-- and add them to the trust policy of your AWS IAM role
DESC INTEGRATION AWS_S3_INTEGRATION;


/* =====================================================================
   STEP 3: EXTERNAL STAGE
   Points to the S3 location where new files will arrive.
   ===================================================================== */
CREATE OR REPLACE STAGE PIPE_STAGE
    FILE_FORMAT = INGEST_DATA
    STORAGE_INTEGRATION = AWS_S3_INTEGRATION
    URL = 's3://<your-bucket-name>/<folder>/';

LIST @PIPE_STAGE;    -- verify Snowflake can see the files in S3


/* =====================================================================
   STEP 4: TARGET TABLE
   The table that Snowpipe loads data into.
   ===================================================================== */
CREATE OR REPLACE TABLE EMPLOYEE_LOAD (
    Emp_id   INT,
    Emp_name VARCHAR(50),
    Company  VARCHAR(30),
    JoinDate DATE,
    Country  VARCHAR(30)
);


/* =====================================================================
   STEP 5: CREATE THE PIPE
   - A pipe wraps a COPY INTO statement.
   - AUTO_INGEST = TRUE: S3 event notifications trigger the load
     automatically when a new file arrives.
   - ON_ERROR = CONTINUE: skip bad records and load the rest
     (the Snowpipe default is SKIP_FILE).
   ===================================================================== */
CREATE OR REPLACE PIPE EMPLOYEE_PIPE
    AUTO_INGEST = TRUE
AS
COPY INTO EMPLOYEE_LOAD
FROM @PIPE_STAGE
ON_ERROR = CONTINUE;

/* ---------------------------------------------------------------------
   STEP 6: ACTIVATE S3 EVENT NOTIFICATIONS (done in AWS)
   1. Run SHOW PIPES and copy the value in the notification_channel
      column. It is an SQS queue ARN managed by Snowflake.
   2. In AWS: S3 bucket > Properties > Event notifications > Create.
   3. Event type: All object create events.
   4. Destination: SQS queue, and paste the notification_channel ARN.
   Without this step, new files will not trigger the pipe.
   --------------------------------------------------------------------- */
SHOW PIPES;    -- displays all pipes and their notification channel


/* =====================================================================
   STEP 7: LOAD FILES THAT WERE ALREADY IN THE STAGE
   A pipe loads only files that arrive AFTER it is created.
   REFRESH queues files already staged (from the last 7 days).
   ===================================================================== */
ALTER PIPE EMPLOYEE_PIPE REFRESH;


/* =====================================================================
   STEP 8: MONITOR AND VERIFY
   ===================================================================== */

-- Pipe state, pending file count, and last ingested file
SELECT SYSTEM$PIPE_STATUS('EMPLOYEE_PIPE');

-- Verify the loaded data
SELECT Emp_id, Emp_name, Company, JoinDate, Country FROM EMPLOYEE_LOAD;

-- Copy history of the pipe, near real time (last 1 hour here)
SELECT *
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    TABLE_NAME => 'EMPLOYEE_LOAD',
    START_TIME => DATEADD(HOUR, -1, CURRENT_TIMESTAMP())));

-- Copy history of the pipe from ACCOUNT_USAGE (can lag by up to 2 hours)
SELECT *
FROM SNOWFLAKE.ACCOUNT_USAGE.COPY_HISTORY
WHERE PIPE_NAME = 'EMPLOYEE_PIPE';

-- Pause and resume the pipe
-- ALTER PIPE EMPLOYEE_PIPE SET PIPE_EXECUTION_PAUSED = TRUE;
-- ALTER PIPE EMPLOYEE_PIPE SET PIPE_EXECUTION_PAUSED = FALSE;


/* =====================================================================
   ERROR MONITORING (email alerts when a file has errors)
   Setup in AWS:
   1. Create an SNS topic.
   2. Create a subscription on the topic: protocol = Email, and enter
      the destination email address.
   3. Confirm the subscription from the email AWS sends you.
   4. In IAM, create a policy that allows publishing to the SNS topic
      (sns:Publish).
   5. Attach the policy to an IAM role that Snowflake can assume.
   6. Create the notification integration in Snowflake (below).
   7. Run DESC INTEGRATION and add the SNOWFLAKE_IAM_USER_ARN and
      external ID to the trust policy of the IAM role.
   ===================================================================== */

/* ---------------------------------------------------------------------
   NOTIFICATION INTEGRATION
   A Snowflake object that lets Snowflake send or receive messages and
   events through a third-party cloud messaging service (here AWS SNS).
   --------------------------------------------------------------------- */
CREATE OR REPLACE NOTIFICATION INTEGRATION SNS_ERROR_INTEGRATION
    ENABLED = TRUE
    TYPE = QUEUE
    DIRECTION = OUTBOUND                  -- Snowflake sends messages to SNS
    NOTIFICATION_PROVIDER = AWS_SNS
    AWS_SNS_TOPIC_ARN = '<your_sns_topic_arn>'
    AWS_SNS_ROLE_ARN = '<your_sns_role_arn>';

DESC INTEGRATION SNS_ERROR_INTEGRATION;

-- Attach the integration to the pipe, so errors are sent to SNS
ALTER PIPE EMPLOYEE_PIPE SET ERROR_INTEGRATION = SNS_ERROR_INTEGRATION;

-- Check which rows or files failed for a specific load
-- SELECT * FROM TABLE(VALIDATE_PIPE_LOAD(
--     PIPE_NAME => 'EMPLOYEE_PIPE',
--     START_TIME => DATEADD(HOUR, -1, CURRENT_TIMESTAMP())));
