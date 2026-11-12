/*
 A2 - Procedimiento corregido (Oracle PL/SQL)
 Supuesto funcional: la transición permitida es PENDIENTE -> PROCESADA.
 La transacción la controla el llamador; este procedimiento NO hace COMMIT.
*/
CREATE OR REPLACE PROCEDURE cerrar_solicitud(p_id IN NUMBER) AS
    v_estado       solicitud.estado%TYPE;
    v_aprobadas    PLS_INTEGER;
BEGIN
    -- Permite revertir únicamente los cambios de esta llamada si algo falla.
    SAVEPOINT sp_cerrar_solicitud;

    -- Serializa cierres concurrentes para la misma solicitud.
    SELECT estado
      INTO v_estado
      FROM solicitud
     WHERE id_solicitud = p_id
       FOR UPDATE;

    -- Idempotencia: no vuelve a tocar ni auditar una solicitud ya procesada.
    IF v_estado = 'PROCESADA' THEN
        RETURN;
    END IF;

    -- Evita transiciones no definidas por el enunciado.
    IF v_estado IS NULL OR v_estado <> 'PENDIENTE' THEN
        RAISE_APPLICATION_ERROR(
            -20002,
            'Estado no elegible para cierre. Se esperaba PENDIENTE.'
        );
    END IF;

    SELECT COUNT(*)
      INTO v_aprobadas
      FROM gestion
     WHERE id_solicitud = p_id
       AND resultado = 'APROBADA';

    -- Sin aprobación no se modifica estado ni auditoría.
    IF v_aprobadas = 0 THEN
        RETURN;
    END IF;

    UPDATE solicitud
       SET estado = 'PROCESADA',
           fecha_actualizacion = SYSDATE
     WHERE id_solicitud = p_id
       AND estado = v_estado;

    IF SQL%ROWCOUNT <> 1 THEN
        RAISE_APPLICATION_ERROR(
            -20003,
            'No fue posible actualizar exactamente una solicitud.'
        );
    END IF;

    -- La auditoría se inserta dentro de la misma transacción que el UPDATE.
    INSERT INTO auditoria_solicitud (
        id,
        id_solicitud,
        estado_anterior,
        estado_nuevo,
        fecha,
        detalle
    ) VALUES (
        seq_auditoria.NEXTVAL,
        p_id,
        v_estado,
        'PROCESADA',
        SYSDATE,
        'Cierre automático validado'
    );

    -- Intencionalmente NO hay COMMIT. El servicio llamador confirma
    -- únicamente cuando toda la operación de negocio finaliza correctamente.
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK TO sp_cerrar_solicitud;
        RAISE_APPLICATION_ERROR(-20001, 'La solicitud indicada no existe.');
    WHEN OTHERS THEN
        ROLLBACK TO sp_cerrar_solicitud;
        RAISE;
END cerrar_solicitud;
/

/* Ejemplo de invocación desde una sesión de pruebas:

BEGIN
    cerrar_solicitud(12345);
    -- Inspeccionar SOLICITUD y AUDITORIA_SOLICITUD en esta misma sesión.
    COMMIT; -- solo si se validó el resultado esperado
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/

Para probar idempotencia, invocar de nuevo después del COMMIT y comprobar
que no se inserta una segunda auditoría.
*/
