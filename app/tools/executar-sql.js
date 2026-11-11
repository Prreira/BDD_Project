// Executa um ficheiro .sql na base de dados eVoto e mostra as mensagens (PRINT)
// e as tabelas de resultados no terminal. Alternativa ao SSMS para a demonstração.
//   npm run sql -- ..\db\05_consultas.sql
//   npm run sql -- ..\db\06_testes_gatilhos.sql
const fs = require('fs');
const sql = require('mssql');
const { config } = require('../db');

(async () => {
  const ficheiro = process.argv[2];
  if (!ficheiro) { console.error('Uso: npm run sql -- <ficheiro.sql>'); process.exit(1); }
  const pool = await new sql.ConnectionPool({ ...config, pool: { max: 1, min: 1 } }).connect();
  try {
    const texto = fs.readFileSync(ficheiro, 'utf8');
    const lotes = texto.split(/^\s*GO\s*$/gim).map((l) => l.trim()).filter(Boolean);
    for (const lote of lotes) {
      const r = pool.request();
      r.on('info', (i) => { if (!/^Changed database context/.test(i.message)) console.log(i.message); });
      const res = await r.batch(lote);
      for (const rs of res.recordsets || []) {
        console.log(`-- ${rs.length} linha(s)`);
        console.table(rs.slice(0, 15).map((l) => Object.fromEntries(
          Object.entries(l).map(([k, v]) => [k, v instanceof Date ? v.toISOString().slice(0, 16).replace('T', ' ') : v]))));
        if (rs.length > 15) console.log(`   ... (+${rs.length - 15} linhas)`);
      }
    }
  } catch (e) {
    console.error('ERRO:', e.message);
    process.exitCode = 1;
  } finally {
    await pool.close();
  }
})();
