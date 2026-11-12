/*
 A1 - Consulta propuesta (Oracle SQL)
 Supuesto: SOLICITUD.ESTADO está normalizado en mayúsculas.
 Revisar semántica y plan real antes de sustituir la consulta productiva.
*/
WITH solicitudes_filtradas AS (
    SELECT
        s.id_solicitud,
        s.documento,
        s.estado,
        s.fecha_creacion
    FROM solicitud s
    WHERE
        -- Conserva el corte desde la medianoche de hace 30 días,
        -- sin aplicar TRUNC sobre la columna indexada.
        s.fecha_creacion >= TRUNC(SYSDATE) - 30

        -- Válido si los valores de estado están normalizados en mayúsculas.
        AND s.estado <> 'CERRADA'

        -- Se requiere un cliente activo; EXISTS expresa existencia
        -- y evita multiplicación de filas si cambia la cardinalidad.
        AND EXISTS (
            SELECT 1
            FROM cliente c
            WHERE c.documento = s.documento
              AND c.activo = 'S'
        )
),
gestiones_ultimas AS (
    SELECT
        g.id_solicitud,
        MAX(g.fecha_gestion) AS ultima_gestion
    FROM gestion g
    INNER JOIN solicitudes_filtradas sf
        ON sf.id_solicitud = g.id_solicitud
    GROUP BY g.id_solicitud
)
SELECT
    sf.id_solicitud,
    sf.documento,
    sf.estado,
    sf.fecha_creacion,
    gu.ultima_gestion
FROM solicitudes_filtradas sf
LEFT JOIN gestiones_ultimas gu
    ON gu.id_solicitud = sf.id_solicitud
ORDER BY sf.fecha_creacion DESC;

/*
 NOTAS DE SEMÁNTICA:
 - LEFT JOIN conserva las solicitudes filtradas que no tienen gestiones;
   ultima_gestion será NULL.
 - NVL(c.activo, 'N') = 'S' y c.activo = 'S' seleccionan lo mismo
   para esta comparación: NULL no se considera activo.
 - UPPER(s.estado) <> 'CERRADA' es insensible a mayúsculas. La versión
   propuesta supone datos canónicos. Si existen valores como 'Cerrada',
   no retirar UPPER sin normalizar datos o usar una expresión equivalente.
 - EXISTS no es necesariamente más rápido que IN; verificar plan y métricas.
 - El optimizador puede inlinear/transformar los CTE. Comparar el plan real.
*/
