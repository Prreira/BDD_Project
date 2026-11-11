// Cria a base de dados eVoto a partir dos scripts em ../db e define a password
// de demonstração dos administradores (bcrypt).   Uso:  npm run setup
// Os eleitores não têm password: autenticam-se com NIF + código de uso único.
const fs = require('fs');
const path = require('path');
const sql = require('mssql');
const bcrypt = require('bcryptjs');
const { config } = require('./db');

const FICHEIROS = ['01_schema.sql', '02_gatilhos.sql', '03_vistas_procedimentos.sql', '04_dados_teste.sql'];
const PASS_ADMIN = 'Admin#2026';

(async () => {
  // ligação única (max 1) para o USE e as tabelas temporárias persistirem entre lotes
  const pool = await new sql.ConnectionPool({ ...config, database: 'master', pool: { max: 1, min: 1 } }).connect();
  try {
    const soPasswords = process.argv.includes('--passwords'); // BD já criada no SSMS
    for (const f of soPasswords ? [] : FICHEIROS) {
      const texto = fs.readFileSync(path.join(__dirname, '..', 'db', f), 'utf8');
      const lotes = texto.split(/^\s*GO\s*$/gim).map((l) => l.trim()).filter(Boolean);
      console.log(`> ${f} (${lotes.length} lotes)`);
      for (const lote of lotes) await pool.request().batch(lote);
    }
    await pool.request().batch('USE eVoto');
    await pool.request().input('a', sql.VarChar, bcrypt.hashSync(PASS_ADMIN, 10))
      .query('UPDATE dbo.Administrador SET password_hash = @a');
    const demo = await pool.request().query(`
      SELECT TOP 3 nif, nome FROM dbo.Eleitor
      WHERE nif NOT IN (SELECT nif FROM dbo.Candidato) ORDER BY nome`);
    console.log('\nBase de dados pronta.');
    console.log(`  Administração:  admin1@evoto.pt / ${PASS_ADMIN}`);
    console.log('  Eleitores (entram com o NIF; o código aparece no ecrã):');
    demo.recordset.forEach((e) => console.log(`    NIF ${e.nif}  ${e.nome}`));
  } catch (e) {
    console.error('Erro no setup:', e.message);
    process.exitCode = 1;
  } finally {
    await pool.close();
  }
})();
