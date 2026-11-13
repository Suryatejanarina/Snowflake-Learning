/* =====================================================================
   Snowflake: Common Table Types
   Covers: Permanent, Transient, Temporary and External tables
   ===================================================================== */ 

USE DATABASE Learning;
USE SCHEMA Learning_Schema;


/* =====================================================================
   1. PERMANENT TABLE
   - Default table type in Snowflake
   - Stays until it is explicitly dropped
   - Time Travel: 1 day by default, up to 90 days (Enterprise edition or higher)
   - Fail-safe: 7 days (recovery handled by Snowflake Support only)
   - Can be cloned as a permanent, transient or temporary table
   - Best for: critical business data
   ===================================================================== */
CREATE OR REPLACE TABLE Employee_Details (
    Empid     INT,
    EmpName   VARCHAR(100),
    Address   VARCHAR(50),
    PhnNumber VARCHAR(12)
);

-- Insert records into Employee_Details
INSERT INTO Employee_Details VALUES
    (1, 'Vishal',    'Bangalore',  '9999922222'),
    (2, 'Kausal',    'Hyderabad',  '9988776655'),
    (3, 'Peter',     'Vijayawada', '9999888877'),
    (4, 'Viswanath', 'Vizag',      '8888777666'),
    (5, 'Phani',     'Hyderabad',  '9999999999');

SELECT Empid, EmpName, Address, PhnNumber FROM Employee_Details;


/* =====================================================================
   2. TRANSIENT TABLE
   - Stays until it is explicitly dropped
   - Time Travel: 0 or 1 day only
   - No Fail-safe, so storage cost is lower
   - Best for: staging data or data that can be recreated easily
   ===================================================================== */
CREATE OR REPLACE TRANSIENT TABLE Customer_Details (
    Customerid   INT,
    CustomerName VARCHAR(100),
    Address      VARCHAR(50),
    PhnNumber    VARCHAR(12)
);

-- Insert records into Customer_Details
INSERT INTO Customer_Details VALUES
    (1, 'Anna',    'Texas',      '212121212'),
    (2, 'Peter',   'Florida',    '5353535353'),
    (3, 'Parker',  'California', '3443344332'),
    (4, 'Alex',    'Texas',      '1322314512'),
    (5, 'Anglena', 'Washington', '236541243');

SELECT Customerid, CustomerName, Address, PhnNumber FROM Customer_Details;


/* =====================================================================
   3. TEMPORARY TABLE
   - Exists only for the current session
   - Automatically dropped when the session ends
   - Visible only to the session that created it
   - Time Travel: 0 or 1 day, no Fail-safe
   - Best for: intermediate results during processing
   ===================================================================== */
CREATE OR REPLACE TEMPORARY TABLE Order_Details (
    Orderid     INT,
    Customerid  INT,
    Productname VARCHAR(100),
    Amount      INT,
    OrderDate   DATE
);

-- Insert records into Order_Details
INSERT INTO Order_Details VALUES
    (1, 2, 'Mobile',       30000, '2026-01-01'),
    (2, 5, 'Water Bottle',   600, '2026-01-02'),
    (3, 1, 'Laptop',       80000, '2026-01-03'),
    (4, 1, 'Mouse',         8000, '2026-01-05'),
    (5, 3, 'Head Phones',  80000, '2026-01-07');

SELECT Orderid, Customerid, Productname, Amount, OrderDate FROM Order_Details;


/* =====================================================================
   4. EXTERNAL TABLE
   - Data stays in external cloud storage (AWS S3, Azure Blob, GCS)
   - Snowflake stores only metadata about the files
   - Read-only: INSERT, UPDATE and DELETE are not allowed
   - Queries are slower than on internal tables
   - Needs an external stage pointing to the storage location
   - Best for: querying data lake files without loading them

   ===================================================================== */

-- Step 1: File format describing the files in cloud storage
CREATE OR REPLACE FILE FORMAT csv_ext_format
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1;

-- Step 2: External stage pointing to the cloud storage location
-- URL = your S3 URL, for example 's3://my-company-bucket/employee-data/'
-- STORAGE_INTEGRATION = integration created by your account admin for S3 access
CREATE OR REPLACE STAGE ext_employee_stage
    URL = 's3://<your-bucket-name>/<your-folder-path>/'   -- replace with your S3 URL
    STORAGE_INTEGRATION = <your_storage_integration>      -- replace with your integration name
    FILE_FORMAT = csv_ext_format;

-- Step 3: Create the external table
-- For CSV files, columns are mapped from the VALUE variant (c1, c2, ...)
-- c1 = 1st column in the file, c2 = 2nd column, and so on
CREATE OR REPLACE EXTERNAL TABLE Ext_Employee_Details (
    Empid     INT          AS (VALUE:c1::INT),
    EmpName   VARCHAR(100) AS (VALUE:c2::VARCHAR),
    Address   VARCHAR(50)  AS (VALUE:c3::VARCHAR),
    PhnNumber VARCHAR(12)  AS (VALUE:c4::VARCHAR)
)
WITH LOCATION = @ext_employee_stage/                      -- stage created in Step 2
AUTO_REFRESH = FALSE                                      -- TRUE only if cloud event notifications are set up
FILE_FORMAT = (FORMAT_NAME = 'csv_ext_format');

-- Step 4: Refresh metadata so Snowflake picks up the files in the stage
ALTER EXTERNAL TABLE Ext_Employee_Details REFRESH;

-- Step 5: Query the external table (read-only)
SELECT Empid, EmpName, Address, PhnNumber FROM Ext_Employee_Details;

SHOW TABLES LIKE '%Details%';
SHOW EXTERNAL TABLES;
