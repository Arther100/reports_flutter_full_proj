const express = require('express');
const sql = require('mssql');
const cors = require('cors');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

// MS SQL Configuration
const sqlConfig = {
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  server: process.env.DB_SERVER,
  port: parseInt(process.env.DB_PORT) || 1433,
  options: {
    encrypt: false,  // Disable encryption for IP address
    trustServerCertificate: true,
    enableArithAbort: true,
  },
  pool: {
    max: 10,
    min: 0,
    idleTimeoutMillis: 30000
  }
};

// Global connection pool
let pool;

// Initialize database connection
async function initializeDatabase() {
  try {
    pool = await sql.connect(sqlConfig);
    console.log('✅ Connected to MS SQL Server');
    console.log(`   Server: ${process.env.DB_SERVER}`);
    console.log(`   Database: ${process.env.DB_NAME}`);
    return true;
  } catch (err) {
    console.error('❌ Database connection failed:', err.message);
    return false;
  }
}

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    database: pool?.connected ? 'connected' : 'disconnected',
    timestamp: new Date().toISOString() 
  });
});

// Get all tables in the database
app.get('/api/tables', async (req, res) => {
  try {
    const result = await pool.request().query(`
      SELECT TABLE_NAME 
      FROM INFORMATION_SCHEMA.TABLES 
      WHERE TABLE_TYPE = 'BASE TABLE'
      ORDER BY TABLE_NAME
    `);
    res.json({ success: true, data: result.recordset });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Get columns for a specific table
app.get('/api/tables/:tableName/columns', async (req, res) => {
  try {
    const { tableName } = req.params;
    const result = await pool.request()
      .input('tableName', sql.VarChar, tableName)
      .query(`
        SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, CHARACTER_MAXIMUM_LENGTH
        FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_NAME = @tableName
        ORDER BY ORDINAL_POSITION
      `);
    res.json({ success: true, data: result.recordset });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Generic query endpoint - Get data from any table
app.get('/api/data/:tableName', async (req, res) => {
  try {
    const { tableName } = req.params;
    const { page = 1, pageSize = 50, orderBy, order = 'DESC' } = req.query;
    
    const offset = (parseInt(page) - 1) * parseInt(pageSize);
    
    // Get total count
    const countResult = await pool.request().query(`
      SELECT COUNT(*) as total FROM [${tableName}]
    `);
    const totalCount = countResult.recordset[0].total;
    
    // Get paginated data
    let query = `
      SELECT * FROM [${tableName}]
      ORDER BY ${orderBy ? `[${orderBy}]` : '(SELECT NULL)'}  ${order}
      OFFSET ${offset} ROWS
      FETCH NEXT ${parseInt(pageSize)} ROWS ONLY
    `;
    
    const result = await pool.request().query(query);
    
    res.json({
      success: true,
      data: result.recordset,
      page: parseInt(page),
      pageSize: parseInt(pageSize),
      totalCount: totalCount,
      totalPages: Math.ceil(totalCount / parseInt(pageSize))
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Execute custom SQL query (for flexibility)
app.post('/api/query', async (req, res) => {
  try {
    const { query } = req.body;
    
    if (!query) {
      return res.status(400).json({ success: false, message: 'Query is required' });
    }
    
    const result = await pool.request().query(query);
    res.json({ 
      success: true, 
      data: result.recordset,
      rowsAffected: result.rowsAffected
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Power Data endpoints (will be customized based on your tables)
app.get('/api/power-data', async (req, res) => {
  try {
    const { page = 1, pageSize = 50 } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(pageSize);
    
    // TODO: Update this query based on your actual table structure
    // For now, let's try to find relevant tables
    const tables = await pool.request().query(`
      SELECT TABLE_NAME 
      FROM INFORMATION_SCHEMA.TABLES 
      WHERE TABLE_TYPE = 'BASE TABLE'
      ORDER BY TABLE_NAME
    `);
    
    res.json({
      success: true,
      message: 'Please specify your power data table. Available tables:',
      tables: tables.recordset.map(t => t.TABLE_NAME),
      data: []
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Get latest data from a table
app.get('/api/data/:tableName/latest', async (req, res) => {
  try {
    const { tableName } = req.params;
    const { limit = 10, dateColumn } = req.query;
    
    let query;
    if (dateColumn) {
      query = `SELECT TOP ${parseInt(limit)} * FROM [${tableName}] ORDER BY [${dateColumn}] DESC`;
    } else {
      query = `SELECT TOP ${parseInt(limit)} * FROM [${tableName}]`;
    }
    
    const result = await pool.request().query(query);
    res.json({ success: true, data: result.recordset });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Dashboard summary
app.get('/api/dashboard', async (req, res) => {
  try {
    // Get list of tables as initial dashboard data
    const tables = await pool.request().query(`
      SELECT TABLE_NAME, 
        (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = t.TABLE_NAME) as ColumnCount
      FROM INFORMATION_SCHEMA.TABLES t
      WHERE TABLE_TYPE = 'BASE TABLE'
      ORDER BY TABLE_NAME
    `);
    
    res.json({
      success: true,
      data: {
        tables: tables.recordset,
        tableCount: tables.recordset.length,
        timestamp: new Date().toISOString()
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Chart data endpoint
app.get('/api/chart-data', async (req, res) => {
  try {
    const { tableName, valueColumn, dateColumn, startDate, endDate } = req.query;
    
    if (!tableName || !valueColumn) {
      return res.json({
        success: false,
        message: 'tableName and valueColumn are required',
        data: []
      });
    }
    
    let query = `
      SELECT [${dateColumn || 'CreatedDate'}] as timestamp, 
             [${valueColumn}] as value
      FROM [${tableName}]
    `;
    
    if (startDate && endDate && dateColumn) {
      query += ` WHERE [${dateColumn}] BETWEEN '${startDate}' AND '${endDate}'`;
    }
    
    query += ` ORDER BY [${dateColumn || 'CreatedDate'}]`;
    
    const result = await pool.request().query(query);
    res.json({ success: true, data: result.recordset });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Statistics endpoint
app.get('/api/data/:tableName/statistics', async (req, res) => {
  try {
    const { tableName } = req.params;
    const { columns } = req.query;
    
    if (!columns) {
      // Return row count only
      const result = await pool.request().query(`
        SELECT COUNT(*) as totalRecords FROM [${tableName}]
      `);
      return res.json({ success: true, data: result.recordset[0] });
    }
    
    // Get statistics for specified numeric columns
    const columnList = columns.split(',');
    const statsQuery = columnList.map(col => `
      SUM([${col.trim()}]) as [${col.trim()}_sum],
      AVG([${col.trim()}]) as [${col.trim()}_avg],
      MAX([${col.trim()}]) as [${col.trim()}_max],
      MIN([${col.trim()}]) as [${col.trim()}_min]
    `).join(', ');
    
    const result = await pool.request().query(`
      SELECT ${statsQuery}, COUNT(*) as totalRecords FROM [${tableName}]
    `);
    
    res.json({ success: true, data: result.recordset[0] });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Start server
const PORT = process.env.PORT || 5000;

initializeDatabase().then((connected) => {
  app.listen(PORT, () => {
    console.log('');
    console.log('═══════════════════════════════════════════════════════════');
    console.log('  🚀 Power Operations API Server');
    console.log('═══════════════════════════════════════════════════════════');
    console.log(`  Server running at: http://localhost:${PORT}`);
    console.log(`  Health check: http://localhost:${PORT}/api/health`);
    console.log(`  List tables: http://localhost:${PORT}/api/tables`);
    console.log('═══════════════════════════════════════════════════════════');
    console.log('');
  });
});
