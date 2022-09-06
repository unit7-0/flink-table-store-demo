Postgres:

CREATE DATABASE shop;

CREATE TABLE products (
  id INTEGER NOT NULL PRIMARY KEY,
  name text NOT NULL,
  description text
);

CREATE TABLE orders (
  order_id INTEGER NOT NULL PRIMARY KEY,
  order_date timestamp without time zone NOT NULL,
  customer_name text NOT NULL,
  price DECIMAL(10, 5) NOT NULL,
  product_id INTEGER NOT NULL,
  order_status BOOLEAN NOT NULL -- Whether order has been placed
);

INSERT INTO products
VALUES (101,'scooter','Small 2-wheel scooter'),
       (102,'car battery','12V car battery'),
       (103,'12-pack drill bits','12-pack of drill bits with sizes ranging from #40 to #3'),
       (104,'hammer','12oz carpenter''s hammer'),
       (105,'hammer','14oz carpenter''s hammer'),
       (106,'hammer','16oz carpenter''s hammer'),
       (107,'rocks','box of assorted rocks'),
       (108,'jacket','water resistent black wind breaker'),
       (109,'spare tire','24 inch spare tire');

INSERT INTO orders
VALUES (10002, '2020-07-30 10:08:22', 'Jark', 50.50, 102, false),
       (10003, '2020-07-30 10:11:09', 'Sally', 15.00, 105, false),
       (10004, '2020-07-30 12:00:30', 'Edward', 25.25, 106, false);


Flink:


SET 'execution.checkpointing.interval' = '3 s';
SET 'execution.runtime-mode' = 'streaming';
SET 'sql-client.execution.result-mode' = 'tableau';


CREATE TABLE products (
    id INT,
    name STRING,
    description STRING,
    PRIMARY KEY (id) NOT ENFORCED
  ) WITH (
    'connector' = 'postgres-cdc',
    'hostname' = 'localhost',
    'port' = '5432',
    'username' = 'postgres',
    'password' = 'postgres',
    'database-name' = 'shop',
    'schema-name' = 'public',
    'table-name' = 'products',
    'debezium.slot.name' = 'products_cdc'
  );

CREATE TABLE orders (
   order_id INT,
   order_date TIMESTAMP(0),
   customer_name STRING,
   price DECIMAL(10, 5),
   product_id INT,
   order_status BOOLEAN,
   PRIMARY KEY (order_id) NOT ENFORCED
 ) WITH (
   'connector' = 'postgres-cdc',
   'hostname' = 'localhost',
   'port' = '5432',
   'username' = 'postgres',
   'password' = 'postgres',
   'database-name' = 'shop',
   'schema-name' = 'public',
   'table-name' = 'orders',
   'debezium.slot.name' = 'orders_cdc'
 );


 SELECT o.*, p.name, p.description
 FROM orders AS o
 LEFT JOIN products AS p ON o.product_id = p.id;