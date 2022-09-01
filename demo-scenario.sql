Postgres:

CREATE DATABASE clients;
CREATE TABLE client(id bigint, name text);

INSERT INTO client VALUES (1, 'Alice'), (2, 'Bob');


Flink:

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

-- external table with clients

CREATE TABLE IF NOT EXISTS clients(
    id BIGINT,
    name STRING
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://postgres:5432/clients',
    'table-name' = 'client',
    'username' = 'postgres',
    'password' = 'postgres',
    'lookup.cache.max-rows' = '1000',
    'lookup.cache.ttl' = '1h'
);

-- external table with processed and marked as good transactions

CREATE TABLE IF NOT EXISTS good_transactions(id BIGINT)
WITH (
    'connector' = 'kafka',
    'topic' = 'good_transactions',
    'properties.bootstrap.servers' = 'kafka:29092',
    'format' = 'json'
);

-- managed table with marked as fraudulent transactions, table changes also logged into kafka topic

CREATE TABLE IF NOT EXISTS fraudulent_txns(
    txn_id BIGINT,
    client_id BIGINT,
    client_name STRING,
    amount DECIMAL,
    type STRING,
    ts TIMESTAMP(2)
) WITH (
    'log.system' = 'kafka',
    'kafka.bootstrap.servers' = 'kafka:29092',
    'kafka.transaction.timeout.ms' = '60000',   -- fails without it
    'kafka.flink.disable-metrics' = 'true'  -- fails without it
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

-- separate good and fraud transactions by status

INSERT INTO analyzed_txns 
SELECT 
    txn_id,
    client_id,
    CASE WHEN txns_num > 5 THEN 'FRAUD' ELSE 'OK' END,
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

-- publish fraud transactions into the separate table

INSERT INTO fraudulent_txns
SELECT 
    t.id AS txn_id,
    t.client_id,
    c.name AS client_name,
    t.amount,
    t.type,
    t.ts
FROM analyzed_txns t JOIN clients c ON t.client_id = c.id WHERE t.result_status = 'FRAUD';

-- publish good transactions into the external table

INSERT INTO good_transactions SELECT id FROM analyzed_txns WHERE result_status <> 'FRAUD';

-- show fraudulent transactions

SELECT * FROM analyzed_txns;

