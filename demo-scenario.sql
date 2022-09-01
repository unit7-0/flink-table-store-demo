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
    'properties.bootstrap.servers' = 'localhost:9092',
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
    'url' = 'jdbc:postgresql://localhost:5432/clients',
    'table-name' = 'clients',
    'username' = 'postgres',
    'password' = 'postgres',
    'lookup.cache.max-rows' = '1000',
    'lookup.cache.ttl' = '1h'
);

-- managed table with fraud detection settings

CREATE TABLE IF NOT EXISTS fraud_settings(s_name STRING, s_value STRING);


-- external table with processed and marked as good transactions

CREATE TABLE IF NOT EXISTS good_transactions(id BIGINT)
WITH (
    'connector' = 'kafka',
    'topic' = 'good_transactions',
    'properties.bootstrap.servers' = 'localhost:9092',
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
    'bootstrap.servers' = 'localhost:9092',
    'log.kafka.transaction.timeout.ms' = '60000',   -- fails without it
    'log.kafka.flink.disable-metrics' = 'true'  -- fails without it
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

-- how much transactions in 10 minutes window by one client should be seen to be considered as fraud

INSERT INTO fraud_settings VALUES ('txns.num.fraud', '5');

-- separate good and fraud transactions by status

INSERT INTO analyzed_txns 
SELECT 
    txn_id,
    client_id,
    CASE WHEN txns_num > CAST(fs.s_value AS INTEGER) THEN 'FRAUD' ELSE 'OK' END,
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
) JOIN fraud_settings fs ON fs.s_name = 'txns.num.fraud';

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


