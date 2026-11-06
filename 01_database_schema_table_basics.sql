/* =====================================================================
   File    : 01_database_schema_table_basics.sql
   Purpose : Create a database, schema and table; insert, view, update
             and delete records; and clean up
   Author  : Your Name
   Created : 2026-11-06
   Notes   : Run top to bottom. The cleanup section at the end is
             commented out on purpose, so it never runs by accident.
   ===================================================================== */


-- ---------------------------------------------------------------------
-- 1. SET CONTEXT (make sure objects are created where you expect)
-- ---------------------------------------------------------------------
-- USE ROLE SYSADMIN;            -- uncomment if you work with specific roles
-- USE WAREHOUSE <your_warehouse>;  -- a running warehouse is needed for INSERT/SELECT


-- ---------------------------------------------------------------------
-- 2. CREATE DATABASE AND SCHEMA
-- ---------------------------------------------------------------------
-- IF NOT EXISTS lets you re-run the script without errors
CREATE DATABASE IF NOT EXISTS LEARNING;

CREATE SCHEMA IF NOT EXISTS LEARNING.LEARNING_SCHEMA;

USE DATABASE LEARNING;
USE SCHEMA LEARNING_SCHEMA;


-- ---------------------------------------------------------------------
-- 3. CREATE TABLE
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS LEARNING.LEARNING_SCHEMA.EMPLOYEE (
    Empid     INT,
    EmpName   VARCHAR(100),
    Address   VARCHAR(50),
    PhnNumber VARCHAR(12)
);


-- ---------------------------------------------------------------------
-- 4. INSPECT OBJECTS
-- ---------------------------------------------------------------------
-- List all tables in the current schema (owner, rows, size, retention)
SHOW TABLES;

-- Show the structure of EMPLOYEE (column names, data types, nullability)
DESC TABLE EMPLOYEE;

-- Show the full CREATE TABLE statement
SELECT GET_DDL('TABLE', 'LEARNING.LEARNING_SCHEMA.EMPLOYEE');


-- ---------------------------------------------------------------------
-- 5. INSERT RECORDS
-- ---------------------------------------------------------------------
-- Insert multiple records in one statement
-- Note: PhnNumber is VARCHAR, so phone numbers are written as text
INSERT INTO EMPLOYEE VALUES
    (1, 'Vishal',    'Bangalore',  '9999922222'),
    (2, 'Kausal',    'Hyderabad',  '9988776655'),
    (3, 'Peter',     'Vijayawada', '9999888877'),
    (4, 'Viswanath', 'Vizag',      '8888777666'),
    (5, 'Phani',     'Hyderabad',  '9999999999');

-- Insert one record, naming the columns explicitly (safer if the table changes)
INSERT INTO EMPLOYEE (Empid, EmpName, Address, PhnNumber)
VALUES (6, 'Naveen', 'Hyderabad', '7878787878');


-- ---------------------------------------------------------------------
-- 6. VERIFY THE DATA
-- ---------------------------------------------------------------------
SELECT * FROM EMPLOYEE ORDER BY Empid;

SELECT COUNT(*) AS total_employees FROM EMPLOYEE;

-- Filter example (text values use single quotes)
SELECT * FROM EMPLOYEE WHERE Address = 'Hyderabad';


-- ---------------------------------------------------------------------
-- 7. UPDATE AND DELETE (always use a WHERE clause)
-- ---------------------------------------------------------------------
-- Change the address of one employee
UPDATE EMPLOYEE
SET Address = 'Chennai'
WHERE Empid = 6;

-- Remove one employee
DELETE FROM EMPLOYEE
WHERE Empid = 6;


-- ---------------------------------------------------------------------
-- 8. CLEANUP (commented out; run one statement at a time when needed)
-- ---------------------------------------------------------------------
-- DELETE vs TRUNCATE vs DROP:
--   DELETE   : removes selected rows (can use WHERE); structure stays
--   TRUNCATE : removes ALL rows quickly; structure stays
--   DROP     : removes the table itself (structure and data)

-- Remove all records, keep the table structure
-- TRUNCATE TABLE EMPLOYEE;

-- Remove the table. It can be restored with UNDROP while it is still
-- inside the Time Travel retention period
-- DROP TABLE EMPLOYEE;

-- Restore a dropped table
-- UNDROP TABLE EMPLOYEE;
