cat << EOF >> /root/sample_app.md
kubectl exec -it -n postgres-db postgres bash
psql -U admin -d postgresdb
CREATE TABLE cars (
  brand VARCHAR(255),
  model VARCHAR(255),
  year INT
);
SELECT * FROM cars;
INSERT INTO cars (brand, model, year)
VALUES ('Ford', 'Mustang', 1964);
INSERT INTO cars (brand, model, year)
VALUES
  ('Volvo', 'p1800', 1968),
  ('BMW', 'M1', 1978),
  ('Toyota', 'Celica', 1975);
SELECT * FROM cars;
EOF


`kubectl exec -it postgres -- bash`{{exec}}
