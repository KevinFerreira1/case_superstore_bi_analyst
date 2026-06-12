# Case Superstore - BI Analyst

Este projeto apresenta a resolução do case Superstore, com foco na construção de um pipeline de dados robusto e na criação de um dashboard estratégico para análise detalhada de vendas, lucros e devoluções.

### Diagrama de Contexto
```mermaid
C4Context
  title System Context Diagram - Superstore BI Architecture

  Person(analyst, "Analista de BI / Stakeholder", "Analisa dados de vendas, lucros e devoluções para a tomada de decisões.")
  
  System_Ext(source, "Planilha Excel (Local)", "Dados brutos transacionais em formato XLSX contendo o histórico da Superstore.")
  
  System(bi_system, "Superstore Data Pipeline", "Extrai, armazena, limpa e modela os dados na nuvem (AWS) de forma orquestrada via Airflow.")
  
  System_Ext(pbi, "Power BI", "Dashboard Estratégico para visualização de relatórios.")

  Rel(analyst, pbi, "Visualiza dashboards e extrai insights")
  Rel(source, bi_system, "Fornece dados de vendas diários")
  Rel(bi_system, pbi, "Disponibiliza os dados modelados prontos para consumo")
```

### Diagrama de Container (Arquitetura Medallion)
```mermaid
C4Container
  title Container Diagram - Pipeline de Dados na Nuvem (AWS) e Orquestração

  System_Ext(source, "Arquivo XLSX", "Fonte de dados original da Superstore")
  System_Ext(pbi, "Power BI", "Camada de Visualização")

  Container_Boundary(aws, "AWS Cloud") {
    ContainerDb(s3_raw, "S3: Raw / Landing", "Parquet", "Armazena dados brutos extraídos do Excel")
    ContainerDb(s3_trusted, "S3: Trusted / Silver", "Parquet", "Dados limpos, padronizados e validados")
    ContainerDb(s3_refined, "S3: Refined / Gold", "Parquet", "Modelagem Dimensional (Star Schema)")
    
    Container(glue, "AWS Glue (Crawlers)", "Data Catalog", "Descobre esquemas automaticamente e preenche o catálogo")
    Container(athena, "AWS Athena", "Query Engine", "Criação de views, operações CTAS e validações SQL")
  }

  Container_Boundary(docker, "Ambiente Docker (Local/Server)") {
    Container(airflow, "Apache Airflow", "Python", "Orquestrador de todo o pipeline de ETL (Controlador e DAGs filhas)")
  }

  Rel(source, airflow, "Extração inicial via Script Python")
  Rel(airflow, s3_raw, "Upload no formato Parquet")
  Rel(s3_raw, glue, "Crawler detecta schema")
  Rel(glue, athena, "Atualiza Catálogo de Dados")
  Rel(airflow, athena, "Executa scripts SQL (Validações e CTAS)")
  Rel(athena, s3_trusted, "Grava na Trusted Zone")
  Rel(athena, s3_refined, "Grava na Refined Zone")
  Rel(s3_refined, pbi, "Consumo de dados via Import/DirectQuery")
```

### Detalhamento da Arquitetura Medallion
O projeto foi estruturado em três camadas principais utilizando o S3:
- **Raw/Landing:** Extração dos dados brutos do arquivo XLSX e conversão imediata para formato colunar (Parquet) via Python, simulando o armazenamento inicial em um Data Lake (AWS S3).
- **Trusted (Silver):** Camada de limpeza e padronização. Foram aplicadas regras estritas de qualidade de dados, como remoção de nulos indesejados, tratamento de categorias e padronização de strings.
- **Refined (Gold):** Camada de modelagem dimensional. Os dados foram estruturados em um robusto *Star Schema* para otimizar a performance, os cruzamentos analíticos e a usabilidade pelo Power BI.

**Uso da AWS:**
- **AWS S3:** Atua como o Storage de objetos, arquivando fisicamente os dados parciais e finais nas três zonas (Raw, Trusted, Refined).
- **AWS Glue (Crawlers):** Utilizado para descobrir automaticamente a estrutura (esquema) dos conjuntos de dados brutos e preencher o AWS Glue Data Catalog com as definições de tabelas prontas para consulta.
- **AWS Athena:** Motor analítico e engine de transformação usado para a criação de views lógicas, execução de operações de criação de tabelas (`CTAS`) e testes de validação SQL.

## Decisões Tomadas
- **Apache Airflow:** Selecionado pela eficiência no agendamento diário e controle seguro de dependências entre tarefas (Ex: as DAGs `materialize_trusted` e `materialize_refined` são coordenadas por uma DAG mestra `orchestrate_superstore`). Se destaca também pelos mecanismos de resiliência (retries automáticos).
- **Infraestrutura AWS (S3, Glue, Athena):** Adoção de arquitetura Serverless para processamento de Big Data (Athena) e armazenamento escalável (S3), o que elimina a necessidade de gestão de servidores de banco de dados e mantém custos sob controle.
- **Formato Parquet:** Escolhido desde a extração inicial por ser altamente compressível e otimizado para leituras analíticas em larga escala. Acelera de forma drástica as queries lidas pelo AWS Athena.
- **Validações de Qualidade em SQL:** Implementação rigorosa de testes na camada Trusted (ex: `validate_negative_returns.sql`, `validate_nulls.sql`) para assegurar a integridade do dashboard final, impedindo que inconsistências afetem a tomada de decisão.
- **Gitflow:** Adoção do fluxo de trabalho Gitflow para versionamento do código. Essa abordagem garante um ciclo de desenvolvimento organizado, com branches isoladas para novas features, protegendo a estabilidade da branch principal (`main`).

## Premissas Adotadas
- O orquestrador foi configurado com um schedule de execução diária (`schedule_interval='@daily'`), assumindo rotinas de cargas diárias para os dados base da loja.
- Em alinhamento com as análises pedidas (ex: *Top 10 Loss-Making Products*), registros contendo **produtos com lucro negativo** foram mantidos no fluxo de dados de forma deliberada para permitir a identificação clara e ação contra os ofensores de margem.

## Principais Transformações Realizadas
- **Limpeza de Dados:** Tratamento de valores ausentes (Nulos) e padronização profunda de strings, garantindo consistência técnica em nomes de produtos, localizações e categorizações.
- **Modelagem Star Schema:** O que antes era uma base transacional única (flat) foi desmembrado em 5 dimensões ricas:
  - `vw_dim_customer` (Cliente)
  - `vw_dim_product` (Produto)
  - `vw_dim_geography` (Geografia)
  - `vw_dim_date` (Data)
  - `vw_dim_shipping` (Envio)
  - E 1 tabela de métricas analíticas: `vw_fact_orders` (Tabela Fato de Pedidos e devoluções).
- **Chaves de Negócio:** Implementação lógica de chaves (Surrogate Keys e Natural Keys) de forma a garantir e forçar a integridade referencial correta entre as tabelas.