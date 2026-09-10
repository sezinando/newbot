# R10 — Glossário v1.0

## 1. Objetivo

Este glossário padroniza a terminologia usada na documentação, implementação, auditoria e validação do **R10 — Exposure Reduction Engine** do EAGOLD.

O foco é manter uma linguagem determinística para descrever exposição, candidatos de redução, simulação, restrições, execução, verificação e reconciliação.

## 2. Termos fundamentais

### Exposure / Exposição
Quantidade líquida de lotes direcionais que permanece após compensar BUY contra SELL.

**Definição:**
`ExposureLots = abs(BuyLots - SellLots)`

Não representa o volume bruto total de posições.

### NetLots
Exposição líquida assinada do basket.

**Definição conceitual:**
`NetLots = BuyLots - SellLots`

Valor positivo indica predominância BUY; valor negativo indica predominância SELL.

### GrossLots
Soma dos lotes BUY e SELL, sem compensação.

`GrossLots = BuyLots + SellLots`

É uma medida importante para avaliar redução do capital/exposição operacional total.

### BuyLots / SellLots
Volumes totais atualmente abertos em BUY e SELL, respectivamente.

### Heavy Direction
Direção que possui maior quantidade de lotes entre BUY e SELL.

É a direção normalmente elegível para uma redução balanceada de exposição quando existe posição no lado oposto.

### Hedge Integrity
Integridade da cobertura entre as duas direções.

A cobertura efetiva é limitada pelo menor lado:

`ActualHedge = min(BuyLots, SellLots)`

Uma ação R10 não deve deteriorar desnecessariamente uma cobertura crítica.

## 3. Redução

### Exposure Reduction
Ação de diminuir a exposição líquida sem criar nova exposição.

O R10 é um **engine de redução**: ele não tem como responsabilidade abrir novas posições para aumentar exposição.

### Balanced Reduction
Redução de lotes no lado pesado e no lado oposto, em quantidades compatíveis, buscando reduzir a exposição líquida e também o gross exposure.

A validade deve ser determinada pela simulação do estado posterior à redução.

### Pair Reduction
Redução financiada por lucro em dois tickets da **mesma direção**: um ticket lucrativo financia a realização parcial de um ticket perdedor.

A simulação deve calcular o estado real após a redução; não deve ser tratada como uma redução BUY/SELL balanceada.

### Profit-Funded Reduction
Redução parcial em que o lucro disponível em uma posição compensa a realização parcial de uma posição perdedora, respeitando os limites econômicos definidos pelo R10.

### Pair Candidate
Candidato de operação formado por um `profitTicket` e um `lossTicket`, ambos pertencentes à mesma direção, com uma quantidade de redução compatível.

## 4. Estado de recuperação

### Recovery Debt
Dívida de recuperação medida a partir do pior nível de equity observado desde o início do ciclo de recuperação.

Definição utilizada na especificação:

`RecoveryDebt = max(0, StartEquity - WorstEquity)`

### Remaining Debt
Valor que ainda separa a equity atual da equity inicial do ciclo.

`RemainingDebt = max(0, StartEquity - CurrentEquity)`

### Recovery Surplus
Excedente de equity acima da equity inicial do ciclo.

`RecoverySurplus = max(0, CurrentEquity - StartEquity)`

### Recovery Realization
Mecanismo associado ao R10.2 para reconhecer/reter resultado positivo dentro das regras de recuperação. A realização não transforma o R10 em um mecanismo de abertura de exposição.

## 5. Pipeline formal do R10

### Measure
Medição do estado atual do basket: lotes BUY/SELL, exposição, gross lots, floating profit, margem e demais variáveis necessárias.

### Classify
Classificação do estado medido para determinar se existem condições para uma redução candidata.

### Generate Candidates
Geração de uma ou mais ações possíveis de redução.

### Simulate
Cálculo do estado esperado depois da ação, antes de enviar ordens ao broker.

### Hard Constraints
Restrições obrigatórias que eliminam candidatos inválidos antes do ranking.

### Lexicographic Ranking
Ordenação determinística dos candidatos válidos por prioridades sucessivas. A ordem formal é:

1. satisfazer hard constraints;
2. não aumentar exposição direcional crítica;
3. reduzir gross exposure;
4. preservar hedge integrity;
5. melhorar margem;
6. melhorar recovery state;
7. melhorar resultado econômico;
8. simplicidade operacional;
9. desempate determinístico.

### Execute
Envio da ação autorizada ao terminal/broker.

### Verify
Confirmação de que o resultado efetivo corresponde ao comportamento esperado e que a exposição não foi aumentada indevidamente.

### Reconcile
Reconciliação entre o estado esperado e o estado efetivamente observado nos tickets e no basket.

### Publish Event
Publicação do resultado da ação para telemetria, auditoria, painel e demais componentes interessados.

## 6. Máquina de estados de uma ação

### DETECTED
Uma condição potencial de redução foi identificada.

### CANDIDATE
Uma ação concreta foi construída a partir do estado observado.

### SIMULATED
O resultado pós-ação foi calculado sem executar ordens.

### AUTHORIZED
O candidato passou pelas restrições e pelo ranking e foi autorizado.

### EXECUTING
A ação está sendo enviada/executada.

### VERIFYING
O engine está verificando o resultado real da execução.

### SUCCESS
A ação foi executada e reconciliada com sucesso.

### RETRY
A ação não foi concluída de forma satisfatória, mas pode ser tentada novamente segundo as regras aplicáveis.

### BLOCK
A ação foi impedida por uma restrição ou condição operacional.

### ABORT
A ação foi interrompida porque sua execução deixou de ser válida ou segura.

## 7. Controle operacional

### Action ID
Identificador único da ação R10. Permite relacionar candidato, execução, verificação, consumo e cooldown.

### Idempotency
Propriedade que impede que a mesma ação lógica seja executada repetidamente como se fossem ações novas.

Fluxo conceitual:

`ACTION_ID → EXECUTE → VERIFY → CONSUME → COOLDOWN`

### Cooldown
Janela mínima após uma ação durante a qual uma nova ação equivalente pode ser bloqueada para evitar repetição excessiva.

### Min Exposure Lots
Exposição mínima definida para permitir uma redução. No runtime, corresponde ao parâmetro `R10MinExposureLots`.

### Pair Minimum Profit
Resultado mínimo esperado para autorizar uma redução por pares. No runtime, corresponde a `R10PairMinProfit`.

### Pair Maximum Lots
Limite máximo de lotes considerado em uma operação de redução por pares. No runtime, corresponde a `R10PairMaxLots`.

## 8. Auditoria e execução

### Ticket Audit
Registro detalhado de uma ação sobre ticket, incluindo identificação da ação, ticket, tipo, lotes, preço, floating P/L, swap, comissão, lotes solicitados, retorno/erro, estado restante, preço/horário de fechamento e resultado realizado.

### Pre-Action State
Estado do basket imediatamente antes da execução.

### Post-Action State
Estado observado imediatamente depois da execução e verificação.

### Exposure Delta
Variação da exposição causada por uma ação.

Uma redução válida não deve produzir aumento de exposição.

### Gross Exposure Delta
Variação do `GrossLots` provocada pela ação.

### Broker Execution
Resultado efetivo da solicitação enviada ao terminal/broker. O resultado real deve prevalecer sobre a expectativa da simulação para fins de reconciliação.

## 9. Termos que não pertencem ao R10

Para preservar a separação de responsabilidades, os seguintes conceitos não devem ser atribuídos ao R10 como responsabilidade própria:

- abrir nova exposição;
- prever direção futura do mercado;
- possuir a lógica de `Recovery Debt` como mecanismo de abertura;
- determinar o passo de recuperação do R11;
- substituir R9 como controlador de hedge;
- usar pesos arbitrários para criar um score composto de basket;
- introduzir um Positive Grid como regra interna do R10.

## 10. Regra de linguagem

Quando houver ambiguidade, a documentação deve distinguir explicitamente:

- **exposição líquida** (`ExposureLots` / `NetLots`);
- **exposição bruta** (`GrossLots`);
- **cobertura efetiva** (`ActualHedge`);
- **redução balanceada** (BUY/SELL);
- **redução por pares** (dois tickets na mesma direção);
- **estado simulado** (antes da execução);
- **estado verificado** (depois da execução).

Essa distinção é obrigatória para evitar que uma redução por pares seja interpretada como hedge balanceado ou que `GrossLots` seja confundido com `ExposureLots`.
