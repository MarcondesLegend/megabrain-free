# `_sh-versions/` — Hooks de megabrain-hub aguardando revisão

> **Origem:** STORY-AGENT-SQUAD-SYNC-2026-05-21 — Fase 2 (2026-05-21)
> **Estratégia:** ADD não REPLACE — versões originais MB intactas, SH versions staged aqui para diff manual.

## O que tem aqui

Hooks que existem nos dois repos (mega-brain + megabrain-hub) com versão de SH MAIOR (+22% a +415%):

| Hook | MB original (size) | SH staged (size) | Delta |
|------|-------------------|------------------|-------|
| `pre-push-validation.sh` | 659B | 3.4KB | +415% |
| `enforce-quality-first.sh` | 1.7KB | 2.8KB | +68% |
| `post-session-heuristics.sh` | 6.3KB | 8.0KB | +28% |
| `pre-prompt-route.sh` | 1.4KB | 1.7KB | +25% |
| `enforce-git-push-authority.sh` | 1.7KB | 2.0KB | +22% |

## Estado atual

- Arquivos originais MB em `.claude/hooks/{hook}.sh` continuam ATIVOS e em uso
- Versões SH aqui são **inertes** — não fazem nada até decisão de merge
- `.claude/settings.json` continua apontando para versões originais MB

## Como decidir o merge (próxima fase)

Para cada hook, comparar diff entre MB e SH version:

```bash
diff -u .claude/hooks/{hook} .claude/hooks/_sh-versions/{hook}
```

Decisões possíveis:
1. **SUBSTITUIR**: copiar SH version sobrescrevendo MB original. Risco: SH pode ter dependências que MB não tem.
2. **MERGE**: cherry-pick mudanças relevantes de SH para MB. Risco: trabalho manual.
3. **MANTER MB**: SH version é específica de megabrain-hub e não se aplica. Risco: zero.
4. **ARQUIVAR**: mover SH version para outputs/ e deletar daqui.

Sem nenhuma destas decisões, o repo está em estado seguro — hooks rodam normalmente com versão MB.

## Por que stagiou em vez de substituir direto

Per CLAUDE.md (Princípio "ADD não REPLACE") e Constitution Art. II (Agent Authority): hooks são código executável governado. Substituição requer revisão humana caso-a-caso, não absorção mecânica.
