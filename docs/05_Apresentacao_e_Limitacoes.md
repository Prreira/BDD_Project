# 5. Apresentação, riscos e limitações

## 5.1 Preparação (véspera e dia)

| Passo | Como |
|---|---|
| Repor os dados com datas atuais | `.\preparar-apresentacao.ps1` (verifica Node.js e SQL Server, recria a BD e arranca). As eleições "Em Curso" duram 180 e 20 dias a partir daqui. |
| Password do SQL Server | Fica na variável de ambiente de utilizador `DB_PASSWORD` (já definida neste PC). Noutro PC: `$env:DB_PASSWORD = "..."` ou o script pede-a. |
| Requisitos da máquina | Node.js 18+, SQL Server 2016 SP1+ com autenticação SQL e TCP/IP, `npm install` feito (`app/`). |
| Sem SSMS | `cd app; npm run sql -- ..\db\05_consultas.sql` e `..\db\06_testes_gatilhos.sql` mostram os resultados no terminal. |
| Plano B | Vídeo curto do fluxo completo e capturas de ecrã (ver `04_Guia_Relatorio_e_Checklist.md` §4.2). |

## 5.2 Roteiro de demonstração (8–10 minutos)

1. **Modelo (1 min):** modelo prévio (`Dados2.sql`) → adaptação (tabela de alterações em `03_Modelo_de_Dados.md` §3.1); realçar `RegistoVoto` vs `Voto`.
2. **Login do eleitor (2 min):** NIF → código gerado pela BD e mostrado no ecrã → entrar. Mostrar (terminal) que `CodigoAcesso` só guarda *hash*: `SELECT nif, estado, tentativas FROM dbo.CodigoAcesso`.
3. **Votar (2 min):** Junta de Freguesia 2026 (lista) → confirmar → comprovativo → tentar votar de novo (recusado) → resultados da Legislativas 2024 (Hondt).
4. **Administração (2 min):** painel em tempo real → eleições → criar uma eleição e percorrer cargos/listas/candidatos/recenseamento → iniciar.
5. **Base de dados (2 min):** `npm run sql -- ..\db\06_testes_gatilhos.sql` (todas `OK`) e algumas consultas (C2 Hondt, C7 divisão relacional, C10 acumulado).

Perguntas prováveis: *como garantem o anonimato?* (tabelas separadas, sem hora, GUID; ver limites em 5.3) · *e se dois pedidos votarem ao mesmo tempo?* (PK `(eleicao, nif)` + transação) · *porque o código aparece no ecrã?* (sem serviços externos; o canal de entrega é trocável) · *o que muda face ao Dados2.sql?* (§3.1).

## 5.3 Limitações assumidas

| Limitação | Porquê / trabalho futuro |
|---|---|
| O código de acesso é apresentado no ecrã (mensagem simulada) | Decisão para não depender de serviços pagos. Em produção, `sp_GerarCodigoAcesso` já gera e valida; falta apenas entregar o código por SMS/email (`OTP_MODO` ≠ `ecra` deixa de o devolver ao browser). |
| Anonimato por separação lógica | Quem tiver acesso total à BD e a registos de rede pode tentar correlações temporais. Mitigado: `Voto` sem hora e com GUID aleatório. Futuro: cifra do voto / voto verificável. |
| Sem HTTPS | Protótipo local; em produção, TLS obrigatório. |
| Sessões em memória | Reiniciar o servidor termina as sessões; futuro: armazenamento persistente (Redis/BD). |
| Sem voto presencial | O projeto é só online: as mesas de voto e a origem `Manual` do `Dados2.sql` original foram removidas (ver `03_Modelo_de_Dados.md` §3.1). |
| Sem testes automáticos da aplicação | Existem testes SQL (`06`) e testes manuais registados no README (§Testes). |
| Autenticação do administrador sem 2.º fator | Futuro: 2FA. |
| A aplicação liga-se ao SQL Server com a conta `sa` | Aceitável em ambiente local de demonstração. Em produção usar um *login* dedicado só com permissões de leitura/escrita nas tabelas e `EXECUTE` nos procedimentos. |
| Mensagens do login revelam se um NIF existe | É a mensagem útil ao utilizador; mitigado por limite de pedidos (15 por IP e 5 códigos por NIF em 10 min). Em produção usar uma mensagem genérica. O endpoint `/api/auth/demo` só existe em modo de demonstração. |
| Hondt com desempate simples | Empate de quocientes resolvido por votos e sigla; uninominais empatadas ficam sem vencedor (2.ª volta não implementada). |
