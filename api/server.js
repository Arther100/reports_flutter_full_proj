const express = require('express');
const sql = require('mssql');
const cors = require('cors');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

// Database Configurations
const databases = {
  rupos_preprod: {
    user: process.env.DB_USER || 'RuposPreProd',
    password: process.env.DB_PASSWORD || 'RuposPreProd',
    database: process.env.DB_NAME || 'RuposPreProd',
    server: process.env.DB_SERVER || '208.91.198.174',
    port: parseInt(process.env.DB_PORT) || 1433,
    options: {
      encrypt: false,
      trustServerCertificate: true,
      enableArithAbort: true,
    },
    pool: {
      max: 10,
      min: 0,
      idleTimeoutMillis: 30000
    }
  },
  teapioca_fpdb: {
    user: 'sa',
    password: 'ciglobal$123',
    database: 'TeapiocaFPDB_local',
    server: '72.167.50.36',
    port: 1433,
    options: {
      encrypt: false,
      trustServerCertificate: true,
      enableArithAbort: true,
    },
    pool: {
      max: 10,
      min: 0,
      idleTimeoutMillis: 30000
    }
  }
};

// Connection pools for each database
const pools = {};
// Auto-select Teapioca database on startup
let currentDatabaseId = 'teapioca_fpdb';

// Initialize database connection
async function initializeDatabase(dbId) {
  try {
    if (!pools[dbId]) {
      const config = databases[dbId];
      if (!config) {
        throw new Error(`Database configuration not found: ${dbId}`);
      }
      pools[dbId] = await new sql.ConnectionPool(config).connect();
      console.log(`✅ Connected to database: ${dbId}`);
      console.log(`   Server: ${config.server}`);
      console.log(`   Database: ${config.database}`);
    }
    return pools[dbId];
  } catch (err) {
    console.error(`❌ Failed to connect to ${dbId}:`, err.message);
    throw err;
  }
}

// Get current pool
function getCurrentPool() {
  return pools[currentDatabaseId];
}

// Health check endpoint
app.get('/api/health', (req, res) => {
  const pool = getCurrentPool();
  res.json({
    status: 'healthy',
    database: pool?.connected ? 'connected' : 'disconnected',
    currentDatabase: currentDatabaseId,
    timestamp: new Date().toISOString()
  });
});

// Get available databases
app.get('/api/databases', (req, res) => {
  const dbList = Object.keys(databases).map(id => {
    return {
      id: id,
      name: databases[id].database,
      server: databases[id].server,
      connected: pools[id]?.connected || false
    };
  });
  res.json({
    success: true,
    data: dbList,
    current: currentDatabaseId
  });
});

// Switch database
app.post('/api/switch-database', async (req, res) => {
  try {
    const { databaseId } = req.body;
    console.log(`📝 Switch database request: ${currentDatabaseId} → ${databaseId}`);
    
    if (!databases[databaseId]) {
      console.log(`❌ Database not found: ${databaseId}`);
      return res.status(400).json({
        success: false,
        message: `Database not found: ${databaseId}`
      });
    }

    await initializeDatabase(databaseId);
    const oldDb = currentDatabaseId;
    currentDatabaseId = databaseId;
    
    console.log(`✅ Successfully switched: ${oldDb} → ${databaseId}`);

    res.json({
      success: true,
      message: `Switched to database: ${databaseId}`,
      currentDatabase: currentDatabaseId
    });
  } catch (err) {
    console.log(`❌ Error switching database:`, err.message);
    res.status(500).json({
      success: false,
      message: err.message
    });
  }
});

// Get all tables in current database
app.get('/api/tables', async (req, res) => {
  try {
    const pool = getCurrentPool();
    if (!pool) {
      return res.status(500).json({
        success: false,
        message: 'No database connection'
      });
    }

    const result = await pool.request().query(`
      SELECT TABLE_NAME 
      FROM INFORMATION_SCHEMA.TABLES 
      WHERE TABLE_TYPE = 'BASE TABLE'
      ORDER BY TABLE_NAME
    `);

    res.json({
      success: true,
      data: result.recordset
    });
  } catch (err) {
    res.status(500).json({
      success: false,
      message: err.message
    });
  }
});

// Get columns for a specific table
app.get('/api/tables/:tableName/columns', async (req, res) => {
  try {
    const pool = getCurrentPool();
    if (!pool) {
      return res.status(500).json({
        success: false,
        message: 'No database connection'
      });
    }

    const { tableName } = req.params;
    const result = await pool.request()
      .input('tableName', sql.VarChar, tableName)
      .query(`
        SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, CHARACTER_MAXIMUM_LENGTH
        FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_NAME = @tableName
        ORDER BY ORDINAL_POSITION
      `);

    res.json({
      success: true,
      data: result.recordset
    });
  } catch (err) {
    res.status(500).json({
      success: false,
      message: err.message
    });
  }
});

// Generic query endpoint - Get data from any table
app.get('/api/data/:tableName', async (req, res) => {
  try {
    const pool = getCurrentPool();
    if (!pool) {
      return res.status(500).json({
        success: false,
        message: 'No database connection'
      });
    }

    const { tableName } = req.params;
    const { page = 1, pageSize = 50, orderBy, order = 'DESC' } = req.query;

    const offset = (parseInt(page) - 1) * parseInt(pageSize);

    // Get total count
    const countResult = await pool.request().query(`
      SELECT COUNT(*) as total FROM [${tableName}]
    `);
    const totalCount = countResult.recordset[0].total;

    // Get paginated data
    const query = `
      SELECT * FROM [${tableName}]
      ORDER BY ${orderBy ? `[${orderBy}]` : '(SELECT NULL)'} ${order}
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
    res.status(500).json({
      success: false,
      message: err.message
    });
  }
});

// Execute custom SQL query
app.post('/api/query', async (req, res) => {
  try {
    const pool = getCurrentPool();
    if (!pool) {
      console.log('❌ No database connection available');
      return res.status(500).json({
        success: false,
        message: 'No database connection'
      });
    }

    const { query } = req.body;

    if (!query) {
      return res.status(400).json({
        success: false,
        message: 'Query is required'
      });
    }

    console.log(`🔍 Executing query on database: ${currentDatabaseId}`);
    console.log(`   Query preview: ${query.substring(0, 100)}...`);

    const result = await pool.request().query(query);
    
    console.log(`✅ Query completed: ${result.recordset.length} rows returned`);

    res.json({
      success: true,
      data: result.recordset,
      rowsAffected: result.rowsAffected,
      currentDatabase: currentDatabaseId
    });
  } catch (err) {
    console.log(`❌ Query error:`, err.message);
    res.status(500).json({
      success: false,
      message: err.message
    });
  }
});

// Get latest data from a table
app.get('/api/data/:tableName/latest', async (req, res) => {
  try {
    const pool = getCurrentPool();
    if (!pool) {
      return res.status(500).json({
        success: false,
        message: 'No database connection'
      });
    }

    const { tableName } = req.params;
    const { limit = 10, dateColumn } = req.query;

    let query;
    if (dateColumn) {
      query = `SELECT TOP ${parseInt(limit)} * FROM [${tableName}] ORDER BY [${dateColumn}] DESC`;
    } else {
      query = `SELECT TOP ${parseInt(limit)} * FROM [${tableName}]`;
    }

    const result = await pool.request().query(query);

    res.json({
      success: true,
      data: result.recordset
    });
  } catch (err) {
    res.status(500).json({
      success: false,
      message: err.message
    });
  }
});

// Dashboard summary
app.get('/api/dashboard', async (req, res) => {
  try {
    const pool = getCurrentPool();
    if (!pool) {
      return res.status(500).json({
        success: false,
        message: 'No database connection'
      });
    }

    const tables = await pool.request().query(`
      SELECT TABLE_NAME, 
        (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = t.TABLE_NAME) as ColumnCount
      FROM INFORMATION_SCHEMA.TABLES t
      WHERE TABLE_TYPE = 'BASE TABLE'
      ORDER BY TABLE_NAME
    `);

    res.json({
      success: true,
      database: currentDatabaseId,
      tables: tables.recordset
    });
  } catch (err) {
    res.status(500).json({
      success: false,
      message: err.message
    });
  }
});

// Statistics endpoint
app.get('/api/data/:tableName/statistics', async (req, res) => {
  try {
    const pool = getCurrentPool();
    if (!pool) {
      return res.status(500).json({
        success: false,
        message: 'No database connection'
      });
    }

    const { tableName } = req.params;
    const { columns } = req.query;

    if (!columns) {
      const result = await pool.request().query(`
        SELECT COUNT(*) as totalRecords FROM [${tableName}]
      `);
      return res.json({
        success: true,
        data: result.recordset[0]
      });
    }

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

    res.json({
      success: true,
      data: result.recordset[0]
    });
  } catch (err) {
    res.status(500).json({
      success: false,
      message: err.message
    });
  }
});

// Start server
const PORT = process.env.PORT || 5000;

// Initialize both databases then start server
Promise.all([
  initializeDatabase('rupos_preprod'),
  initializeDatabase('teapioca_fpdb')
]).then(() => {
  app.listen(PORT, () => {
    console.log('');
    console.log('═══════════════════════════════════════════════════════════');
    console.log('  🚀 Multi-Database Power Operations API Server');
    console.log('═══════════════════════════════════════════════════════════');
    console.log(`  Server running at: http://localhost:${PORT}`);
    console.log(`  Health check: http://localhost:${PORT}/api/health`);
    console.log(`  Switch DB: POST http://localhost:${PORT}/api/switch-database`);
    console.log(`  Databases: http://localhost:${PORT}/api/databases`);
    console.log(`  List tables: http://localhost:${PORT}/api/tables`);
    console.log('  ');
    console.log('  📊 Connected Databases:');
    console.log('     • TeapiocaFPDB_local (PowerBI Store) - DEFAULT');
    console.log('     • RuposPreProd (POS Analytics)');
    console.log('═══════════════════════════════════════════════════════════');
    console.log('');
  });
}).catch(err => {
  console.error('❌ Failed to initialize databases:', err.message);
  console.log('');
  console.log('⚠️  Starting server with limited functionality...');
  console.log('   Only successfully connected databases will be available.');
  console.log('');
  
  app.listen(PORT, () => {
    console.log(`Server running at: http://localhost:${PORT}`);
  });
});
