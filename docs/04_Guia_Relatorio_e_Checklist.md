# 4. Guia do relatório e checklist final

## 4.1 Estrutura sugerida do relatório (cada capítulo = um critério de avaliação)

| Cap. | Conteúdo | Origem | Peso |
|---|---|---|---|
| 1 | Introdução e âmbito | `01_Requisitos.md` §1.1 | – |
| 2 | Requisitos funcionais e não funcionais | `01_Requisitos.md` | 5% |
| 3 | Modelação UML de requisitos | `02_*.md` + diagramas `uml/01–05` exportados em imagem | 15% |
| 4 | Modelo da BD e modelo relacional | `03_Modelo_de_Dados.md` §3.1–3.5 + `uml/06–07` (incluir a tabela de alterações ao `Dados2.sql`) | 15% |
| 5 | Gatilhos e asserções | `03_*.md` §3.6 + `db/02_gatilhos.sql` + saída de `06_testes_gatilhos.sql` | 10% |
| 6 | Interrogações SQL | `db/05_consultas.sql` + capturas dos resultados | 15% |
| 7 | Interfaces gráficas | capturas de ecrã (ver 4.2) | 10% |
| 8 | Conclusões e trabalho futuro | ver 4.4 | – |

## 4.2 Capturas de ecrã a incluir (Interfaces)

1. Entrada (separador Eleitor, passo 1: NIF). 2. Passo 2 com a **notificação do código** e o campo preenchido. 3. Entrada da administração.
4. Lista de eleições do eleitor. 5. Boletim de voto. 6. Confirmação e comprovativo. 7. Resultados de eleição apurada (mandatos).
8. Painel (indicadores e gráficos). 9. Gestão de eleições e modal "Gerir". 10. Eleitores. 11. Autenticações. 12. Auditoria.

## 4.3 Como exportar os diagramas

Extensão PlantUML do VS Code → *Export Current Diagram* (PNG/SVG), ou <https://www.plantuml.com/plantuml>. Legendar cada figura (Figura n – …).

## 4.4 Conclusões / trabalho futuro (sugestão)

- Entrega real do código por SMS/email (basta trocar o canal: o procedimento já gera e valida o código) e/ou Chave Móvel Digital; HTTPS obrigatório e 2FA para administradores.
- Voto verificável de ponta-a-ponta (cifra do voto, contagem pública verificável) e voto presencial (exigiria voltar a modelar mesas de voto).
- Replicação/alta disponibilidade, cópias de segurança, *Always Encrypted* e Row-Level Security.

## 4.5 Checklist de coerência (rever antes de entregar)

- [ ] Cada requisito RF tem um caso de uso UC e um ecrã (matriz em `01_Requisitos.md` §1.5).
- [ ] Os nomes de tabelas/atributos são iguais no UML de classes, no ER, no modelo relacional e no script SQL (snake_case do `Dados2.sql`).
- [ ] `npm run setup` corre numa BD vazia sem erros; `06_testes_gatilhos.sql` imprime só `OK`.
- [ ] As 17 consultas correm (C14 devolve 0 linhas por desenho: é a asserção de integridade; C13 devolve os 2 eleitores inativos ainda recenseados).
- [ ] Anonimato do voto explicado (§3.2 do modelo) e visível na BD (`Voto` sem ligação ao eleitor, GUID).
- [ ] Capturas de ecrã atuais (a eleição "Em Curso" depende da data a que correu o *seed*).
- [ ] Cada elemento do grupo sabe explicar **todas** as partes (útil também para a defesa).

## 4.6 Notas para a demonstração

- Se a "Presidencial 2026" tiver encerrado entre o *setup* e a demonstração, volte a correr `npm run setup` (recria tudo com datas relativas ao momento atual).
- Para mostrar o código de acesso na BD: `SELECT nif, criado_em, expira_em, estado, tentativas FROM dbo.CodigoAcesso;` (só há *hash*, nunca o código).
- Para mostrar o anonimato: `SELECT * FROM dbo.RegistoVoto; SELECT * FROM dbo.Voto;` — nenhuma coluna permite cruzar as duas.
- Ver também `05_Apresentacao_e_Limitacoes.md` (roteiro, riscos e limitações).
- Para mostrar a Hondt: `SELECT * FROM dbo.vw_ResultadosLista;` na eleição autárquica.
