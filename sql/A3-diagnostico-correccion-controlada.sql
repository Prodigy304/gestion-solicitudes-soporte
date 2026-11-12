/*
 A3 - Diagnóstico y corrección controlada (Oracle)

a. Ejecutar primero la previsualización y guardar el listado.
b. Confirmar funcionalmente que PENDIENTE es el estado de reversa.
c. El bloque correctivo tiene el interruptor FALSE por defecto.
d. El bloque NO hace COMMIT; verificar y decidir COMMIT o ROLLBACK.
*/

/* 1. PREVISUALIZACIÓN: no modifica datos. */
SELECT
    s.id_solicitud,
    s.documento,
    s.estado,
    s.fecha_creacion,
    s.fecha_actualizacion,
    (SELECT COUNT(*)
       FROM gestion g
      WHERE g.id_solicitud = s.id_solicitud) AS total_gestiones
FROM solicitud s
WHERE s.estado = 'PROCESADA'
  AND NOT EXISTS (
      SELECT 1
      FROM gestion g
      WHERE g.id_solicitud = s.id_solicitud
        AND g.resultado = 'APROBADA'
  )
ORDER BY s.id_solicitud;

/* 2. CORRECCIÓN: mantener FALSE hasta recibir aprobación funcional. */
SET SERVEROUTPUT ON;

DECLARE
    -- Cambiar a TRUE solo después de aprobar y revisar el listado anterior.
    v_confirmar_correccion CONSTANT BOOLEAN := FALSE;
    v_actualizadas PLS_INTEGER := 0;
    v_auditadas    PLS_INTEGER := 0;
BEGIN
    SAVEPOINT sp_correccion_soporte;

    IF NOT v_confirmar_correccion THEN
        DBMS_OUTPUT.PUT_LINE(
            'SIMULACION: no se modificaron filas. Revise candidatos y autorización.'
        );
    ELSE
        FOR r IN (
            SELECT s.id_solicitud, s.estado
            FROM solicitud s
            WHERE s.estado = 'PROCESADA'
              AND NOT EXISTS (
                  SELECT 1
                  FROM gestion g
                  WHERE g.id_solicitud = s.id_solicitud
                    AND g.resultado = 'APROBADA'
              )
            ORDER BY s.id_solicitud
            FOR UPDATE OF s.estado
        ) LOOP
            -- Revalida criterio justo antes de modificar; evita actuar sobre
            -- filas que hayan cambiado desde la previsualización.
            UPDATE solicitud s
               SET estado = 'PENDIENTE',
                   fecha_actualizacion = SYSDATE
             WHERE s.id_solicitud = r.id_solicitud
               AND s.estado = 'PROCESADA'
               AND NOT EXISTS (
                   SELECT 1
                   FROM gestion g
                   WHERE g.id_solicitud = s.id_solicitud
                     AND g.resultado = 'APROBADA'
               );

            IF SQL%ROWCOUNT = 1 THEN
                v_actualizadas := v_actualizadas + 1;

                INSERT INTO auditoria_solicitud (
                    id,
                    id_solicitud,
                    estado_anterior,
                    estado_nuevo,
                    fecha,
                    detalle
                ) VALUES (
                    seq_auditoria.NEXTVAL,
                    r.id_solicitud,
                    r.estado,
                    'PENDIENTE',
                    SYSDATE,
                    'Reversión controlada: procesada sin gestión aprobada; requiere revisión'
                );

                v_auditadas := v_auditadas + 1;
            END IF;
        END LOOP;

        IF v_actualizadas <> v_auditadas THEN
            RAISE_APPLICATION_ERROR(
                -20010,
                'Descuadre: filas actualizadas y auditorías insertadas no coinciden.'
            );
        END IF;

        DBMS_OUTPUT.PUT_LINE('Filas actualizadas: ' || v_actualizadas);
        DBMS_OUTPUT.PUT_LINE('Auditorias insertadas: ' || v_auditadas);
        DBMS_OUTPUT.PUT_LINE(
            'Pendiente: ejecutar verificaciones y decidir COMMIT o ROLLBACK.'
        );
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK TO sp_correccion_soporte;
        RAISE;
END;
/

/* 3. VERIFICACIÓN POSTERIOR, en la MISMA sesión y antes del COMMIT. */
SELECT COUNT(*) AS candidatos_restantes
FROM solicitud s
WHERE s.estado = 'PROCESADA'
  AND NOT EXISTS (
      SELECT 1
      FROM gestion g
      WHERE g.id_solicitud = s.id_solicitud
        AND g.resultado = 'APROBADA'
  );

/* Revisar auditorías recientes. Acotar por fecha de ejecución y/o IDs del
   listado exportado; no usar solo un rango amplio en bases con alta actividad. */
SELECT id, id_solicitud, estado_anterior, estado_nuevo, fecha, detalle
FROM auditoria_solicitud
WHERE detalle LIKE 'Reversión controlada:%'
ORDER BY fecha DESC, id_solicitud;

/* 4. Decisión manual en la sesión:

COMMIT;   -- únicamente cuando candidatos, filas y auditorías fueron validados.
ROLLBACK; -- si algo no coincide; revierte update + auditoría de este bloque.

Después de COMMIT, no borrar/modificar auditorías para "deshacer" historia.
Una reversa posterior debe ser una nueva transición compensatoria auditada.
*/
