/* A1 - Evidencia para el diagnóstico de rendimiento (Oracle) */

/* 1. Revisar estadísticas y tamaños; requiere permisos sobre vistas DBA_*. */
SELECT table_name, num_rows, blocks, last_analyzed
FROM user_tables
WHERE table_name IN ('SOLICITUD', 'GESTION', 'CLIENTE');

SELECT index_name, table_name, uniqueness, status, num_rows,
       distinct_keys, leaf_blocks, clustering_factor, last_analyzed
FROM user_indexes
WHERE table_name IN ('SOLICITUD', 'GESTION', 'CLIENTE');

/* 2. Consultar definición y columnas de los índices reportados. */
SELECT index_name, table_name, column_position, column_name, descend
FROM user_ind_columns
WHERE table_name IN ('SOLICITUD', 'GESTION', 'CLIENTE')
ORDER BY table_name, index_name, column_position;

/* 3. Explicar el SQL propuesto. EXPLAIN PLAN ofrece estimaciones, no ejecución real. */
EXPLAIN PLAN FOR
WITH solicitudes_filtradas AS (
    SELECT s.id_solicitud, s.documento, s.estado, s.fecha_creacion
    FROM solicitud s
    WHERE s.fecha_creacion >= TRUNC(SYSDATE) - 30
      AND s.estado <> 'CERRADA'
      AND EXISTS (
          SELECT 1
          FROM cliente c
          WHERE c.documento = s.documento
            AND c.activo = 'S'
      )
),
gestiones_ultimas AS (
    SELECT g.id_solicitud, MAX(g.fecha_gestion) AS ultima_gestion
    FROM gestion g
    INNER JOIN solicitudes_filtradas sf
        ON sf.id_solicitud = g.id_solicitud
    GROUP BY g.id_solicitud
)
SELECT sf.id_solicitud, sf.documento, sf.estado, sf.fecha_creacion,
       gu.ultima_gestion
FROM solicitudes_filtradas sf
LEFT JOIN gestiones_ultimas gu
    ON gu.id_solicitud = sf.id_solicitud
ORDER BY sf.fecha_creacion DESC;

SELECT *
FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL,
    'BASIC +PREDICATE +COST +CARDINALITY +BYTES'));

/*
 4. Para estadísticas reales:
    - Ejecutar la consulta bajo una sesión de prueba representativa.
    - Si está permitido, añadir el hint GATHER_PLAN_STATISTICS al SELECT.
    - Inmediatamente después, identificar SQL_ID y child number y consultar:

 SELECT *
 FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(
     '<SQL_ID>', <CHILD_NUMBER>,
     'ALLSTATS LAST +PREDICATE +PEEKED_BINDS'));

  El acceso a cursores/vistas dinámicas depende de privilegios.
  Comparar A-Rows vs E-Rows, Buffers, Reads, A-Time, Starts y uso de TEMP.
*/

/* 5. Índice candidato: NO ejecutar hasta justificarlo con mediciones.

CREATE INDEX IDX_GESTION_SOL_FECHA
    ON GESTION (ID_SOLICITUD, FECHA_GESTION);

Después de crearlo en ambiente de prueba:
- volver a recopilar estadísticas según el estándar DBA;
- comparar plan y métricas antes/después;
- medir costo en INSERT/UPDATE y espacio ocupado;
- retirar el índice si no produce beneficio sostenible.
*/
