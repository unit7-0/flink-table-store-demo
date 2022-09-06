SET 'table-store.root-path' = '/tmp/table_store';
SET 'execution.checkpointing.interval' = '10 s';
SET 'execution.runtime-mode' = 'streaming';

-- external table with incoming transactions

CREATE TABLE IF NOT EXISTS transactions(
    id BIGINT,
    clientId BIGINT,
    amount DECIMAL,
    type STRING,
    ts TIMESTAMP(3),
    WATERMARK FOR ts AS ts
) WITH (
    'connector' = 'kafka',
    'topic' = 'transactions',
    'properties.bootstrap.servers' = 'kafka:29092',
    'properties.group.id' = 'fraud-detector',
    'format' = 'json',
    'scan.startup.mode' = 'earliest-offset'
);

-- managed table with processed transactions with analysis result status

CREATE TABLE IF NOT EXISTS analyzed_txns(
    id BIGINT,
    client_id BIGINT,
    result_status STRING,
    amount DECIMAL,
    type STRING,
    ts TIMESTAMP(2)
) WITH ('write-mode' = 'append-only');

-- create user defined function to call it in the query bellow

CREATE FUNCTION isFraud AS 'ru.neoflex.flink.IsFraudFunction' LANGUAGE SCALA;

-- separate good and fraud transactions by status

INSERT INTO analyzed_txns 
SELECT 
    txn_id,
    client_id,
    isFraud(txns_num),
    amount,
    type,
    ts FROM (
        SELECT 
            id AS txn_id,
            clientId AS client_id,
            amount,
            type,
            ts,
            COUNT(*) OVER (PARTITION BY clientId ORDER BY ts RANGE BETWEEN INTERVAL '10' MINUTES PRECEDING AND CURRENT ROW) AS txns_num
        FROM transactions
);
