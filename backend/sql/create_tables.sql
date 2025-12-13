-- Power Operations Database Schema
-- Run this script on your MS SQL Server to create the required tables

-- Create database if not exists
-- CREATE DATABASE PowerOperationsDB;
-- GO
-- USE PowerOperationsDB;
-- GO

-- =====================================================
-- Table: stations
-- Description: Power generation stations
-- =====================================================
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='stations' AND xtype='U')
BEGIN
    CREATE TABLE stations (
        id INT IDENTITY(1,1) PRIMARY KEY,
        name NVARCHAR(100) NOT NULL,
        location NVARCHAR(200),
        capacity DECIMAL(18,2) NOT NULL DEFAULT 0,
        type NVARCHAR(50) NOT NULL DEFAULT 'thermal',
        is_active BIT NOT NULL DEFAULT 1,
        last_maintenance DATETIME,
        created_at DATETIME NOT NULL DEFAULT GETDATE(),
        updated_at DATETIME NOT NULL DEFAULT GETDATE()
    );
    
    -- Create index for faster queries
    CREATE INDEX IX_stations_name ON stations(name);
    CREATE INDEX IX_stations_is_active ON stations(is_active);
END
GO

-- =====================================================
-- Table: power_data
-- Description: Power readings/measurements
-- =====================================================
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='power_data' AND xtype='U')
BEGIN
    CREATE TABLE power_data (
        id BIGINT IDENTITY(1,1) PRIMARY KEY,
        station_id INT NOT NULL,
        station_name NVARCHAR(100) NOT NULL,
        power_generated DECIMAL(18,4) NOT NULL DEFAULT 0,
        power_consumed DECIMAL(18,4) NOT NULL DEFAULT 0,
        voltage DECIMAL(18,4) NOT NULL DEFAULT 0,
        current DECIMAL(18,4) NOT NULL DEFAULT 0,
        frequency DECIMAL(10,4) NOT NULL DEFAULT 50.0,
        power_factor DECIMAL(6,4) NOT NULL DEFAULT 0.85,
        efficiency DECIMAL(8,4) NOT NULL DEFAULT 0,
        status NVARCHAR(20) NOT NULL DEFAULT 'active',
        timestamp DATETIME NOT NULL DEFAULT GETDATE(),
        created_at DATETIME NOT NULL DEFAULT GETDATE(),
        
        CONSTRAINT FK_power_data_station FOREIGN KEY (station_id) 
            REFERENCES stations(id) ON DELETE CASCADE
    );
    
    -- Create indexes for fast querying (especially for charts)
    CREATE INDEX IX_power_data_timestamp ON power_data(timestamp DESC);
    CREATE INDEX IX_power_data_station_id ON power_data(station_id);
    CREATE INDEX IX_power_data_station_name ON power_data(station_name);
    CREATE INDEX IX_power_data_station_timestamp ON power_data(station_id, timestamp DESC);
    
    -- Composite index for common query patterns
    CREATE INDEX IX_power_data_query ON power_data(station_name, timestamp DESC) 
        INCLUDE (power_generated, power_consumed, efficiency);
END
GO

-- =====================================================
-- Insert sample data for testing
-- =====================================================
-- Sample Stations
IF NOT EXISTS (SELECT TOP 1 1 FROM stations)
BEGIN
    INSERT INTO stations (name, location, capacity, type, is_active, last_maintenance)
    VALUES 
        ('Main Power Plant', 'Industrial Zone A', 1000.00, 'thermal', 1, DATEADD(DAY, -30, GETDATE())),
        ('Solar Farm Alpha', 'Desert Region B', 500.00, 'solar', 1, DATEADD(DAY, -15, GETDATE())),
        ('Wind Farm Delta', 'Coastal Area C', 750.00, 'wind', 1, DATEADD(DAY, -45, GETDATE())),
        ('Hydro Station Gamma', 'River Valley D', 600.00, 'hydro', 1, DATEADD(DAY, -20, GETDATE())),
        ('Gas Turbine Unit', 'City Center E', 400.00, 'gas', 1, DATEADD(DAY, -10, GETDATE()));
END
GO

-- =====================================================
-- Stored Procedure: Insert sample power data
-- =====================================================
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'sp_InsertSamplePowerData')
    DROP PROCEDURE sp_InsertSamplePowerData;
GO

CREATE PROCEDURE sp_InsertSamplePowerData
    @NumRecords INT = 1000
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @i INT = 0;
    DECLARE @stationId INT;
    DECLARE @stationName NVARCHAR(100);
    DECLARE @timestamp DATETIME;
    DECLARE @baseGenerated DECIMAL(18,4);
    DECLARE @baseConsumed DECIMAL(18,4);
    
    WHILE @i < @NumRecords
    BEGIN
        -- Random station selection
        SELECT TOP 1 @stationId = id, @stationName = name 
        FROM stations 
        ORDER BY NEWID();
        
        -- Generate timestamp going back in time
        SET @timestamp = DATEADD(MINUTE, -@i * 5, GETDATE());
        
        -- Generate realistic values with some variation
        SET @baseGenerated = 100 + (RAND() * 150);
        SET @baseConsumed = @baseGenerated * (0.7 + RAND() * 0.2);
        
        INSERT INTO power_data (
            station_id,
            station_name,
            power_generated,
            power_consumed,
            voltage,
            current,
            frequency,
            power_factor,
            efficiency,
            status,
            timestamp
        )
        VALUES (
            @stationId,
            @stationName,
            @baseGenerated,
            @baseConsumed,
            220 + (RAND() * 20) - 10,           -- Voltage: 210-230
            40 + (RAND() * 30),                  -- Current: 40-70
            50 + (RAND() * 0.4) - 0.2,          -- Frequency: 49.8-50.2
            0.85 + (RAND() * 0.1),              -- Power Factor: 0.85-0.95
            (@baseConsumed / @baseGenerated) * 100, -- Efficiency %
            CASE 
                WHEN RAND() < 0.9 THEN 'active'
                WHEN RAND() < 0.95 THEN 'warning'
                ELSE 'maintenance'
            END,
            @timestamp
        );
        
        SET @i = @i + 1;
    END
    
    PRINT 'Inserted ' + CAST(@NumRecords AS VARCHAR) + ' sample records.';
END
GO

-- Execute to insert sample data (uncomment to run)
-- EXEC sp_InsertSamplePowerData @NumRecords = 5000;
-- GO

-- =====================================================
-- Useful Views for faster querying
-- =====================================================
IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_LatestPowerData')
    DROP VIEW vw_LatestPowerData;
GO

CREATE VIEW vw_LatestPowerData AS
SELECT 
    pd.*
FROM power_data pd
INNER JOIN (
    SELECT station_id, MAX(timestamp) as max_timestamp
    FROM power_data
    GROUP BY station_id
) latest ON pd.station_id = latest.station_id AND pd.timestamp = latest.max_timestamp;
GO

-- =====================================================
-- View: Power Statistics Summary
-- =====================================================
IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_PowerStatistics')
    DROP VIEW vw_PowerStatistics;
GO

CREATE VIEW vw_PowerStatistics AS
SELECT 
    SUM(power_generated) as total_generated,
    SUM(power_consumed) as total_consumed,
    AVG(efficiency) as average_efficiency,
    MAX(power_generated) as peak_power,
    MIN(power_generated) as min_power,
    AVG(power_factor) as average_power_factor,
    COUNT(*) as total_readings,
    MAX(timestamp) as last_updated
FROM power_data;
GO

PRINT 'Database schema created successfully!';
GO
