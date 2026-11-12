# 2. Plan de validación y pruebas

## SQL A1 - rendimiento

| Prueba | Entrada/condición | Resultado esperado | Qué demuestra |
|---|---|---|---|
| Equivalencia de fechas | Filas en medianoche, durante el día límite, antes y después | Mismo conjunto que el filtro original en la ventana de 30 días | La eliminación de `TRUNC` sobre la columna conserva el límite temporal. |
| Cliente activo | `activo='S'`, `'N'` y `NULL` | Solo documentos con `'S'` | Conservación de semántica de `NVL(...,'N')='S'`. |
| Estado | `CERRADA`, `PENDIENTE`, NULL y posibles valores en minúscula | Excluir `CERRADA` y NULL; comportamiento case-sensitive solo si se confirma normalización | Valida el supuesto de estados canónicos. |
| Solicitud sin gestiones | Solicitud candidata sin filas en GESTION | Aparece con `ultima_gestion = NULL` | `LEFT JOIN` no elimina solicitudes. |
| Plan / carga | Dataset y carga equivalentes; SQL original y propuesto | Comparar elapsed, CPU, buffer gets, physical reads, filas, sort/TEMP | Decide si la mejora es real. |

## PL/SQL A2 - consistencia

| Caso | Preparación | Resultado esperado |
|---|---|---|
| Cierre correcto | Solicitud PENDIENTE con una gestión APROBADA | PROCESADA + una auditoría PENDIENTE→PROCESADA en la misma transacción. |
| Reintento | Ejecutar de nuevo luego de confirmar el cierre | Sin nueva actualización ni auditoría adicional. |
| Sin aprobación | Solicitud PENDIENTE sin gestión APROBADA | Sin cambios. |
| ID inexistente | ID no registrado | Error funcional -20001; sin cambios. |
| Estado no permitido | Solicitud en estado distinto de PENDIENTE/PROCESADA | Error funcional; sin cambios. |
| Auditoría falla | Forzar fallo del INSERT en entorno de prueba | La actualización se revierte al savepoint y la excepción se propaga. |
| Concurrencia | Dos sesiones llaman con el mismo ID | Bloqueo por fila; una sola transición y una sola auditoría. |

## A3 - corrección controlada

1. Ejecutar la previsualización y guardar/exportar el conjunto de IDs.
2. Verificar manualmente un muestreo y confirmar con negocio el estado de reversa.
3. Activar el interruptor únicamente con autorización explícita.
4. Ejecutar el bloque en una única sesión transaccional.
5. Consultar nuevamente candidatos y auditoría antes del `COMMIT`.
6. Si los conteos no coinciden o hay un resultado inesperado, ejecutar `ROLLBACK`.
7. Si la validación es correcta, confirmar el cambio con `COMMIT` autorizado.

Invariante de control: cantidad de filas realmente actualizadas debe ser igual a cantidad de auditorías insertadas. El bloque aborta ante un error de auditoría y revierte su propio trabajo al savepoint.

## Java - ejecución local

```bash
cd java
./run-tests.sh
```

El script compila producción y pruebas con `javac` y ejecuta el test harness con assertions activadas (`-ea`). Resultado esperado: todos los casos aparecen como `OK` y finaliza con `RESULTADO: 5 pruebas superadas`.

## Limitaciones de validación

- No se dispone de conexión, DDL completo, datos ni estadísticas de Oracle; los scripts SQL/PLSQL no se ejecutaron contra una instancia real.
- No se adjuntó el proyecto Spring/JPA original. La lógica Java se compila y prueba aislada, pero falta validar mappings, transacción, serialización del DTO, controlador y manejo HTTP reales.
- El repositorio fake verifica lógica de servicio; no prueba el orden de la consulta real del repositorio JPA ni la concurrencia de base de datos.
