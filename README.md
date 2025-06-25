# superset-setup
Helper for setting up superset on a Ubuntu server 22.04

## run
sign-in as `simsage` user, and run 
```
# run <full-domain-name> <db-password>
sudo ./initial-server-setup.sh superset.simsage.ai fiefai7TaiTeeng6Ohx5

# restart the server, it'll need to update a few things

# populate your two cert files in /opt/cert/
sudo nano /opt/cert/cert-chain.txt
sudo nano /opt/cert/key.txt
sudo systemctl restart nginx

# then create your initial admin user, make sure to sign-out to
# get the docker group associated properly with the simsage user
docker exec -it superset superset fab create-admin
```

## useful SQL queries for our parquet files

```sql
--------------- PII union SQL

SELECT
  'Credit Card Count' AS "Category",
  count(id) AS "Value"
FROM
  data
WHERE
  credit_card_count > 0

UNION ALL

SELECT
  'Phone Count' AS "Category",
  count(id) AS "Value"
FROM
  data
WHERE
  phone_count > 0

UNION ALL

SELECT
  'Person Count' AS "Category",
  count(id) AS "Value"
FROM
  data
WHERE
  person_count > 0

UNION ALL

SELECT
  'VAT Count' AS "Category",
  count(id) AS "Value"
FROM
  data
WHERE
  vat_count > 0
  
UNION ALL

SELECT
  'URL Count' AS "Category",
  count(id) AS "Value"
FROM
  data
WHERE
  url_count > 0
  
UNION ALL

SELECT
  'Postcode Count' AS "Category",
  count(id) AS "Value"
FROM
  data
WHERE
  postcode_count > 0
  
UNION ALL

SELECT
  'IP Address Count' AS "Category",
  count(id) AS "Value"
FROM
  data
WHERE
  ip_address_count > 0
  
UNION ALL

SELECT
  'API Secret Count' AS "Category",
  count(id) AS "Value"
FROM
  data
WHERE
  secret_count > 0
  
UNION ALL

SELECT
  'Country Count' AS "Category",
  count(id) AS "Value"
FROM
  data
WHERE
  country_count > 0
```

```sql
--------------- Duplicate Pivot SQL

SELECT id, full_path, content_hash FROM data WHERE id > 0 AND content_hash != '' AND content_hash IN (SELECT content_hash FROM data GROUP BY content_hash HAVING COUNT(*) > 1) ORDER BY content_hash, id;

-- must be a pivot table,  columns: content_hash, rows: full_path, top 500
```

```sql
--------------- Document Sizes SQL

SELECT id, full_path, size FROM data where size > 0;
```

```sql
--------------- Document last-modified SQL

SELECT id, full_path, to_timestamp(last_modified / 1000.0) FROM data where last_modified > 0;
```

```sql
--------------- Document Authorship SQL

SELECT author AS author_name, COUNT(id) as document_count FROM data WHERE author != '' GROUP BY author ORDER BY document_count DESC;
```

```sql
--------------- Document Language SQL

SELECT language AS document_language, COUNT(id) as document_count FROM data WHERE language != '' GROUP BY language ORDER BY document_count DESC;
```

```sql
--------------- Document Type/Size SQL

SELECT extension AS document_type, COUNT(id) as document_count, SUM(size) AS total_size FROM data WHERE extension != '' GROUP BY extension ORDER BY document_count DESC;
```
