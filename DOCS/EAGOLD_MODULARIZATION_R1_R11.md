# EAGOLD — Modularização R1–R11

Base: `EAGOLD(1).mq4` fornecido em 2026-09-10.

## Objetivo

Separar o EA monolítico por responsabilidade, mantendo as regras de negócio inalteradas nesta primeira etapa.

## Responsabilidades

- `EA/core/EAGOLD_CONFIG.mqh` — inputs/configuração.
- `EA/core/EAGOLD_STATE.mqh` — estado de runtime e cálculo de recovery step.
- `EA/core/EAGOLD_UTILS.mqh` — identidade, normalização, contagem, exposição e lucro.
- `EA/core/EAGOLD_ORDERS.mqh` — primitives de execução de ordens.
- `EA/core/EAGOLD_PERSISTENCE.mqh` — persistência em Global Variables.
- `EA/engines/R1_FIRST_ENGINE.mqh` — R1/R1.1.
- `EA/engines/R4_R5_R7_LIFECYCLE.mqh` — R4/R5/R7.
- `EA/engines/R9_HEDGE.mqh` — R9.
- `EA/engines/R10_REDUCTION.mqh` — R10.
- `EA/engines/R10_2_RECOVERY_REALIZATION.mqh` — R10.2.
- `EA/engines/R11_RECOVERY_STEP.mqh` — R11.
- `EA/telemetry/EAGOLD_TELEMETRY.mqh` — R12 telemetry.
- `EA/ui/EAGOLD_MARKERS.mqh` — marcadores visuais.
- `EA/ui/EAGOLD_PANEL.mqh` — painel.
- `EA/EAGOLD.mq4` — orquestração/event handlers.

## Regra de segurança da refatoração

Não alterar thresholds, fórmulas, ordem de execução ou critérios de entrada/saída durante a extração.
Primeiro compilar e comparar com a versão monolítica; somente depois otimizar ou redesenhar.

## Estado deste branch

Os módulos de configuração, estado, utilitários, ordens, R1, R4/R5/R7, R9, R10, R10.2, R11,
telemetria e UI já foram extraídos. A integração final do arquivo principal deve ser validada no
MetaEditor antes de substituir o EA de produção, especialmente a camada de persistência.
