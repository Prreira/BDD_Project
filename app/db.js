// Ligação ao SQL Server (autenticação SQL). Configurar por variáveis de ambiente.
const sql = require('mssql');

const config = {
  server: process.env.DB_SERVER || 'localhost',
  port: process.env.DB_PORT ? parseInt(process.env.DB_PORT, 10) : 1433,
  database: process.env.DB_NAME || 'eVoto',
  user: process.env.DB_USER || 'sa',
  password: process.env.DB_PASSWORD || '',
  options: {
    encrypt: process.env.DB_ENCRYPT === 'true',
    trustServerCertificate: true,
    useUTC: false, // datas em hora local, coerente com SYSDATETIME() do SQL Server
  },
  pool: { max: Number(process.env.DB_POOL_MAX || 10), min: 0, idleTimeoutMillis: 30000 },
};
// com instanceName o porto deve ser omitido (usa o SQL Browser)
if (process.env.DB_INSTANCE) { config.options.instanceName = process.env.DB_INSTANCE; delete config.port; }

let poolPromise = null;
function getPool() {
  if (!poolPromise) {
    poolPromise = new sql.ConnectionPool(config).connect().catch((e) => {
      poolPromise = null;
      throw e;
    });
  }
  return poolPromise;
}

// Executa uma função dentro de uma transação, com o autor da ação (ex.: 'ADMIN:1')
// no SESSION_CONTEXT para que os gatilhos de auditoria saibam quem agiu.
async function runAs(autor, fn) {
  const pool = await getPool();
  const tx = new sql.Transaction(pool);
  await tx.begin();
  try {
    await new sql.Request(tx).input('u', sql.NVarChar(40), autor)
      .query("EXEC sp_set_session_context N'autor', @u");
    const result = await fn(() => new sql.Request(tx));
    await tx.commit();
    return result;
  } catch (e) {
    try { await tx.rollback(); } catch (_) { /* já foi desfeita pelo gatilho */ }
    throw e;
  }
}

module.exports = { sql, config, getPool, runAs };
