# Flink Table Store Demo

## Main scenario

The main demo scenario is located in the [demo-scenario.sql](demo-scenario.sql) file. There are SQL queries with comments 
which should be executed sequentially in PostgreSQL and Flink SQL client.

Firstly, you need to create `libs` directory, download some flink libraries and put them into this directory.

- [flink-table-store-dist-0.2.0.jar](https://repo1.maven.org/maven2/org/apache/flink/flink-table-store-dist/0.2.0/flink-table-store-dist-0.2.0.jar)
- [postgresql-42.5.0.jar](https://repo1.maven.org/maven2/org/postgresql/postgresql/42.5.0/postgresql-42.5.0.jar)
- [flink-connector-jdbc-1.15.2.jar](https://repo1.maven.org/maven2/org/apache/flink/flink-connector-jdbc/1.15.2/flink-connector-jdbc-1.15.2.jar)
- [flink-shaded-hadoop-2-uber-2.8.3-10.0.jar](https://repo1.maven.org/maven2/org/apache/flink/flink-shaded-hadoop-2-uber/2.8.3-10.0/flink-shaded-hadoop-2-uber-2.8.3-10.0.jar)

Before running this scenario you need to up demo infrastructure which is located in the [docker-compose.yaml](docker-compose.yaml) file:

`docker-compose up -d`

Execute the command below to run queries in postgres:

`docker-compose exec postgres psql --user postgres`

Execute the command below to enter to the flink job manager container:

`docker-compose exec jobmanager bash`

And in the container:

`bin/sql-client.sh embedded`


## UDF demo

To run example with user defined function you need to build sbt project, package jar and put it to the libs directory.

```shell
sbt package
mv target/scala-2.12/nf-flink-functions_2.12-0.1.0-SNAPSHOT.jar libs/
```

All demo queries is located in the [user-defined-function-example.sql](user-defined-function-example.sql) file.


## Postgres CDC connector

All demo queries is located in the [cdc-streaming-example.sql](cdc-streaming-example.sql), but before running them
you need to download the postgres cdc connector [flink-sql-connector-postgres-cdc-2.2.1.jar](https://repo1.maven.org/maven2/com/ververica/flink-sql-connector-postgres-cdc/2.2.1/flink-sql-connector-postgres-cdc-2.2.1.jar)
and put it to the libs directory.


## Spark SQL

To select data from a table stored in the flink table store you need to download additional jar
[flink-table-store-spark-0.2.0.jar](https://repo1.maven.org/maven2/org/apache/flink/flink-table-store-spark/0.2.0/flink-table-store-spark-0.2.0.jar),
put it to the `$SPARK_HOME/jars` directory or run spark-sql with `--jars` option like below:

`bin/spark-sql --jars flink-table-store-spark-0.2.0.jar`

Create managed table in the flink sql client:
```postgres-sql
CREATE TABLE orders_stored(order_id INT PRIMARY KEY, order_date TIMESTAMP(0), customer_name STRING, price DECIMAL(10, 5), product_id INT, product_name STRING, product_desc STRING);
```

Run flink streaming query which will insert rows from the tables from previous CDC demo:
```postgres-sql
INSERT INTO orders_stored 
SELECT o.order_id, o.order_date, o.customer_name, o.price, o.product_id, p.name, p.description
FROM orders o
LEFT JOIN products p ON o.product_id = p.id;
```

Further in spark-sql console. Create view to the just created managed table:

```postgres-sql
CREATE TEMPORARY VIEW v_orders
USING tablestore
OPTIONS (
    path "/tmp/table_store/default_catalog.catalog/default_database.db/orders_stored"
);
```

Select data in the spark-sql console:

```postgres-sql
SELECT * FROM v_orders;
```
