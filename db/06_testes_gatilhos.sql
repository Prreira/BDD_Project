/* =====================================================================
   06_testes_gatilhos.sql : demonstração de cada gatilho/restrição e do
   fluxo de código de acesso. Cada teste corre dentro de uma transação que
   é sempre desfeita (exceto o fluxo do código, que só escreve em
   CodigoAcesso/LogAutenticacao), por isso quase não altera os dados.
   Saída esperada: "OK ..." em todas as linhas.
   ===================================================================== */
USE eVoto;
GO
SET NOCOUNT ON;

DECLARE @pres NVARCHAR(200) = N'Eleição Presidencial 2026';
DECLARE @fre  NVARCHAR(200) = N'Eleição da Junta de Freguesia 2027';
DECLARE @aut  NVARCHAR(200) = N'Eleições Autárquicas 2025 - Assembleia Municipal';
DECLARE @votou NVARCHAR(9) = (SELECT TOP 1 nif FROM dbo.RegistoVoto WHERE eleicao = @pres ORDER BY nif);          -- já votou
DECLARE @livre NVARCHAR(9) = (SELECT TOP 1 r.nif FROM dbo.Recenseamento r WHERE r.eleicao = @pres
                              AND NOT EXISTS (SELECT 1 FROM dbo.RegistoVoto v WHERE v.eleicao = r.eleicao AND v.nif = r.nif)
                              ORDER BY r.nif);                                                                    -- ainda não votou
DECLARE @cand NVARCHAR(9) = (SELECT TOP 1 nif FROM dbo.Candidato WHERE eleicao = @pres ORDER BY nif);
DECLARE @json NVARCHAR(MAX) = CONCAT(N'[{"cargo":"Presidente da República","tipo":"Valido","nif":"', @cand, N'"}]');

PRINT N'--- PK: eleitor que já votou volta a votar (deve falhar) ---';
BEGIN TRY
    BEGIN TRAN; EXEC dbo.sp_RegistarVoto @votou, @pres, @json; ROLLBACK;
    PRINT N'FALHOU: o segundo voto foi aceite.';
END TRY
BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; PRINT N'OK  bloqueado: ' + ERROR_MESSAGE(); END CATCH;

PRINT N'--- G1: registo de voto numa eleição Agendada (deve falhar) ---';
BEGIN TRY
    BEGIN TRAN; INSERT dbo.RegistoVoto (eleicao, nif)
        SELECT TOP 1 eleicao, nif FROM dbo.Recenseamento WHERE eleicao = @fre; ROLLBACK;
    PRINT N'FALHOU: voto aceite numa eleição não iniciada.';
END TRY
BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; PRINT N'OK  bloqueado: ' + ERROR_MESSAGE(); END CATCH;

PRINT N'--- FK RegistoVoto->Recenseamento: NIF não recenseado (deve falhar) ---';
BEGIN TRY
    BEGIN TRAN; INSERT dbo.RegistoVoto (eleicao, nif) VALUES (@pres, dbo.fn_NifCompletar('29999999')); ROLLBACK;
    PRINT N'FALHOU: registo aceite.';
END TRY
BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; PRINT N'OK  bloqueado: ' + ERROR_MESSAGE(); END CATCH;

PRINT N'--- G2: alterar um registo de voto (deve falhar) ---';
BEGIN TRY
    BEGIN TRAN; UPDATE dbo.RegistoVoto SET data_hora = GETDATE() WHERE nif = @votou; ROLLBACK;
    PRINT N'FALHOU: registo alterado.';
END TRY
BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; PRINT N'OK  bloqueado: ' + ERROR_MESSAGE(); END CATCH;

PRINT N'--- G5: apagar votos (deve falhar) ---';
BEGIN TRY
    BEGIN TRAN; DELETE FROM dbo.Voto WHERE eleicao = @pres; ROLLBACK;
    PRINT N'FALHOU: votos apagados.';
END TRY
BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; PRINT N'OK  bloqueado: ' + ERROR_MESSAGE(); END CATCH;

PRINT N'--- G6: acrescentar um candidato a eleição em curso (deve falhar) ---';
BEGIN TRY
    BEGIN TRAN; INSERT dbo.Candidato (eleicao, nif, cargo)
        SELECT @pres, nif, N'Presidente da República' FROM dbo.Eleitor WHERE nif = @livre; ROLLBACK;
    PRINT N'FALHOU: candidato inserido.';
END TRY
BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; PRINT N'OK  bloqueado: ' + ERROR_MESSAGE(); END CATCH;

PRINT N'--- G6: retirar eleitor do recenseamento de eleição em curso (deve falhar) ---';
BEGIN TRY
    BEGIN TRAN; DELETE FROM dbo.Recenseamento WHERE eleicao = @pres AND nif = @livre; ROLLBACK;
    PRINT N'FALHOU: recenseamento alterado.';
END TRY
BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; PRINT N'OK  bloqueado: ' + ERROR_MESSAGE(); END CATCH;

PRINT N'--- G7: candidato sem lista numa eleição por Lista (deve falhar) ---';
BEGIN TRY
    BEGIN TRAN; INSERT dbo.Candidato (eleicao, nif, cargo) VALUES (@fre, @livre, N'Junta de Freguesia'); ROLLBACK;
    PRINT N'FALHOU: candidato incoerente aceite.';
END TRY
BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; PRINT N'OK  bloqueado: ' + ERROR_MESSAGE(); END CATCH;

PRINT N'--- G8: transição inválida Agendada -> Encerrada (deve falhar) ---';
BEGIN TRY
    BEGIN TRAN; UPDATE dbo.Eleicao SET estado = 'Encerrada' WHERE nome = @fre; ROLLBACK;
    PRINT N'FALHOU: transição aceite.';
END TRY
BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; PRINT N'OK  bloqueado: ' + ERROR_MESSAGE(); END CATCH;

PRINT N'--- G8: iniciar eleição sem cargos/recenseados/listas (deve falhar) ---';
BEGIN TRY
    BEGIN TRAN;
    INSERT dbo.Eleicao (nome, data_inicio, data_fim, tipo_escrutinio) VALUES (N'Teste vazia', GETDATE(), DATEADD(DAY, 1, GETDATE()), 'Lista');
    UPDATE dbo.Eleicao SET estado = 'Em Curso' WHERE nome = N'Teste vazia';
    ROLLBACK;
    PRINT N'FALHOU: eleição vazia iniciada.';
END TRY
BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; PRINT N'OK  bloqueado: ' + ERROR_MESSAGE(); END CATCH;

PRINT N'--- G8: mudar a data de início de eleição em curso (deve falhar) ---';
BEGIN TRY
    BEGIN TRAN; UPDATE dbo.Eleicao SET data_inicio = DATEADD(DAY, -5, data_inicio) WHERE nome = @pres; ROLLBACK;
    PRINT N'FALHOU: data alterada.';
END TRY
BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; PRINT N'OK  bloqueado: ' + ERROR_MESSAGE(); END CATCH;

PRINT N'--- G10: eleitor menor de idade (deve falhar) ---';
BEGIN TRY
    BEGIN TRAN; INSERT dbo.Eleitor (nif, nome, data_nascimento) VALUES (dbo.fn_NifCompletar('29999998'), N'Menor', DATEADD(YEAR, -16, GETDATE())); ROLLBACK;
    PRINT N'FALHOU: menor aceite.';
END TRY
BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; PRINT N'OK  bloqueado: ' + ERROR_MESSAGE(); END CATCH;

PRINT N'--- CHECK: NIF com dígito de controlo inválido (deve falhar) ---';
BEGIN TRY
    BEGIN TRAN; INSERT dbo.Eleitor (nif, nome, data_nascimento) VALUES (N'123456788', N'NIF inválido', '1990-01-01'); ROLLBACK;
    PRINT N'FALHOU: NIF inválido aceite.';
END TRY
BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; PRINT N'OK  bloqueado: ' + ERROR_MESSAGE(); END CATCH;

PRINT N'--- CHECK Voto: voto válido sem destino (deve falhar) ---';
BEGIN TRY
    BEGIN TRAN; INSERT dbo.Voto (eleicao, tipo_voto) VALUES (@pres, 'Valido'); ROLLBACK;
    PRINT N'FALHOU: voto incoerente aceite.';
END TRY
BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; PRINT N'OK  bloqueado: ' + ERROR_MESSAGE(); END CATCH;

PRINT N'--- G4: inserir um voto numa eleição já apurada (deve falhar) ---';
BEGIN TRY
    BEGIN TRAN; INSERT dbo.Voto (eleicao, tipo_voto, sigla_lista) VALUES (@aut, 'Valido', N'PH'); ROLLBACK;
    PRINT N'FALHOU: voto aceite em eleição encerrada.';
END TRY
BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; PRINT N'OK  bloqueado: ' + ERROR_MESSAGE(); END CATCH;

PRINT N'--- Caso de SUCESSO: voto válido de um eleitor que ainda não votou (deve passar) ---';
BEGIN TRY
    BEGIN TRAN;
    EXEC dbo.sp_RegistarVoto @livre, @pres, @json;
    DECLARE @antes INT = (SELECT COUNT(*) FROM dbo.RegistoVoto WHERE eleicao = @pres) - 1;
    DECLARE @n INT = (SELECT COUNT(*) FROM dbo.RegistoVoto WHERE eleicao = @pres);
    DECLARE @v INT = (SELECT COUNT(*) FROM dbo.Voto WHERE eleicao = @pres AND tipo_voto IS NOT NULL);
    PRINT N'OK  voto registado; registos = ' + CAST(@n AS NVARCHAR(10)) + N', votos = ' + CAST(@v AS NVARCHAR(10)) + N' (antes: ' + CAST(@antes AS NVARCHAR(10)) + N').';
    ROLLBACK;
END TRY
BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; PRINT N'FALHOU: ' + ERROR_MESSAGE(); END CATCH;

/* ------------------- Código de acesso (NIF + código) ------------------- */
DECLARE @nif NVARCHAR(9) = @livre;
DECLARE @c TABLE (codigo CHAR(6), expira_em DATETIME, validade_segundos INT);

PRINT N'--- NIF inválido ao pedir código (deve falhar) ---';
BEGIN TRY EXEC dbo.sp_GerarCodigoAcesso N'123456788'; PRINT N'FALHOU.'; END TRY
BEGIN CATCH PRINT N'OK  bloqueado: ' + ERROR_MESSAGE(); END CATCH;

PRINT N'--- Pedir código, errar, e acertar ---';
INSERT @c EXEC dbo.sp_GerarCodigoAcesso @nif;
DECLARE @codigo CHAR(6) = (SELECT codigo FROM @c);
PRINT N'OK  código gerado (6 dígitos): ' + CASE WHEN @codigo LIKE '[0-9][0-9][0-9][0-9][0-9][0-9]' THEN N'formato válido' ELSE N'FORMATO INVÁLIDO' END;
BEGIN TRY EXEC dbo.sp_ValidarCodigoAcesso @nif, N'000000'; PRINT N'(código 000000 aceite por coincidência)'; END TRY
BEGIN CATCH PRINT N'OK  código errado rejeitado: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC dbo.sp_ValidarCodigoAcesso @nif, @codigo; PRINT N'OK  código correto aceite.'; END TRY
BEGIN CATCH PRINT N'FALHOU: ' + ERROR_MESSAGE(); END CATCH;
BEGIN TRY EXEC dbo.sp_ValidarCodigoAcesso @nif, @codigo; PRINT N'FALHOU: código reutilizado.'; END TRY
BEGIN CATCH PRINT N'OK  reutilização bloqueada (uso único): ' + ERROR_MESSAGE(); END CATCH;
GO
