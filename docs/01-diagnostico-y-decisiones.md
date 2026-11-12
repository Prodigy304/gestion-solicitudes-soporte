# 1. Diagnóstico y decisiones técnicas

## A1. Diagnóstico de la consulta lenta

### A1.1 Hallazgos sobre la consulta original

Consulta evaluada: la que filtra `SOLICITUD` por fecha, estado y documentos de clientes activos, calcula `MAX(GESTION.fecha_gestion)` mediante una subconsulta correlacionada y ordena por fecha descendente.

| Hallazgo | Evidencia en el SQL | Impacto probable | Tratamiento propuesto |
|---|---|---|---|
| Función sobre la columna de fecha | `TRUNC(s.fecha_creacion)` | Puede impedir un acceso eficiente por rango usando `IDX_SOLICITUD_FECHA(fecha_creacion)`. | Comparar la columna sin transformarla: `s.fecha_creacion >= TRUNC(SYSDATE) - 30`. |
| Función sobre estado | `UPPER(s.estado)` | La expresión puede impedir el uso directo de `IDX_SOLICITUD_ESTADO`; además `<>` suele ser poco selectivo. | Si los estados ya están normalizados en mayúsculas, usar `s.estado <> 'CERRADA'`. Si no están normalizados, conservar semántica y evaluar normalización o índice basado en función. |
| Función sobre activo | `NVL(c.activo, 'N') = 'S'` | La expresión aplica una función a `CLIENTE.activo`; la utilidad de un índice simple sobre esa columna puede reducirse. | `c.activo = 'S'` es equivalente para seleccionar activos bajo la regla de que NULL no es activo. Confirmar distribución y semántica. |
| Subconsulta escalar correlacionada | `SELECT MAX(g.fecha_gestion) ... WHERE g.id_solicitud = s.id_solicitud` | Puede implicar búsquedas repetidas en `GESTION` para las filas candidatas. El optimizador puede transformar la consulta, por lo que debe medirse. | Preagregar gestiones para el conjunto de solicitudes filtradas y unir el resultado. Evaluar índice compuesto `(id_solicitud, fecha_gestion)`. |
| Filtro de cliente | `documento IN (SELECT ...)` | No es necesariamente un defecto: Oracle puede resolverlo como semijoin. | Se expresa con `EXISTS` para hacer explícita la condición de existencia y evitar multiplicar solicitudes si cambia el modelo. No afirmar una mejora sin plan. |
| Ordenamiento | `ORDER BY s.fecha_creacion DESC` | Puede requerir un sort, uso de memoria o TEMP, dependiendo del plan y del índice elegido. | Revisar filas de entrada, memoria/TEMP y si el índice de fecha permite evitar o reducir el sort. No crear otro índice solo por intuición. |
| Falta de evidencia de ejecución | El enunciado solo informa volumen e índices. | No se conoce el plan real, cardinalidad estimada/real, lecturas ni distribución. | Medir con plan real y estadísticas antes de desplegar. |

**Semántica de fechas:** el predicado original `TRUNC(s.fecha_creacion) >= TRUNC(SYSDATE - 30)` incluye desde la medianoche del día límite. La reescritura `s.fecha_creacion >= TRUNC(SYSDATE) - 30` conserva ese límite sin aplicar `TRUNC` a la columna. No se agrega un límite superior porque el original tampoco lo tiene.

**Semántica de NULL:** tanto `UPPER(NULL) <> 'CERRADA'` como `NULL <> 'CERRADA'` resultan UNKNOWN en Oracle y no pasan el `WHERE`. `NVL(c.activo,'N')='S'` y `c.activo='S'` seleccionan las mismas filas para esta comparación.

### A1.2 Consulta propuesta

Ver `sql/A1-consulta-optimizada.sql`. Se filtran primero las solicitudes candidatas, se calculan sus últimas gestiones mediante `MAX` y se hace `LEFT JOIN` para no eliminar solicitudes sin gestiones. `EXISTS` conserva la semántica de pertenencia a un cliente activo.

La reescritura no garantiza por sí sola un plan más rápido: Oracle puede hacer inline de los CTE y transformar el SQL. La decisión final depende de `DBMS_XPLAN.DISPLAY_CURSOR` con estadísticas reales y de medir el mismo rango temporal y carga.

### A1.3 Índice candidato y costo

Índice candidato, sujeto a prueba:

```sql
CREATE INDEX IDX_GESTION_SOL_FECHA
    ON GESTION (ID_SOLICITUD, FECHA_GESTION);
```

Justificación: el acceso correlaciona por `ID_SOLICITUD` y obtiene `MAX(FECHA_GESTION)`. Al tener ambas columnas en el índice, puede reducir visitas a la tabla y facilitar el cálculo de la última fecha.

Riesgos/costos: espacio adicional, mayor costo de `INSERT`/`UPDATE`/`DELETE` en `GESTION`, tiempo de creación, posible consumo de I/O y competencia por recursos. Debe evaluarse el tamaño, la frecuencia de escritura, clustering factor, selectividad y mejora medida. No se recomienda crearlo si el plan real ya usa un acceso adecuado o si el costo de mantenimiento supera el beneficio.

No se recomienda agregar de inmediato un índice amplio a `SOLICITUD`: ya existe un índice por fecha, y el cambio de predicado puede permitir aprovecharlo. La condición negativa sobre estado podría ser poco selectiva.

### A1.4 Evidencia previa a producción

1. `DBMS_XPLAN.DISPLAY_CURSOR` con `ALLSTATS LAST`, predicados, cardinalidad estimada y real.
2. SQL_ID, child cursor, bind values cuando aplique y plan hash value.
3. Buffer gets, physical reads, elapsed time, CPU, filas procesadas y número de ejecuciones.
4. Cantidad de solicitudes creadas en los últimos 30 días, distribución por estado, clientes activos y gestiones por solicitud.
5. Estadísticas de tablas/índices, histogramas cuando sean pertinentes, clustering factor y tamaño de índices.
6. Sorts, uso de TEMP, esperas y concurrencia durante la franja lenta.
7. Comparación A/B con mismo conjunto de datos y carga representativa; rollback del cambio si empeoran latencia o recursos.

## A2. Comprensión y corrección de PL/SQL

### A2.1 Qué hace el procedimiento original

1. Cuenta gestiones con `resultado = 'APROBADA'` para `p_id`.
2. Si existe al menos una, actualiza la solicitud a `PROCESADA` y cambia `fecha_actualizacion`.
3. Ejecuta `COMMIT`.
4. Inserta la fila de auditoría indicando siempre `PENDIENTE` → `PROCESADA`.
5. Si cualquier instrucción falla, `WHEN OTHERS THEN NULL` ignora el error y no informa al llamador.

### A2.2 Defectos y riesgos

- **Transacción parcial:** el `COMMIT` ocurre antes del `INSERT` de auditoría. Si este falla, la solicitud queda procesada sin auditoría.
- **Excepciones ocultas:** `WHEN OTHERS THEN NULL` suprime errores de SQL, restricciones, secuencias y otros fallos; soporte pierde diagnóstico.
- **Estado anterior hardcodeado:** la auditoría afirma que el estado era `PENDIENTE` aunque no lo consulta ni valida.
- **Sin manejo de inexistencia:** no distingue una solicitud inexistente de otros casos.
- **No contempla estado ya procesado:** una nueva llamada podría actualizar fecha y agregar auditorías duplicadas.
- **Concurrencia:** no bloquea la fila antes de comprobar/actualizar. Dos ejecuciones concurrentes pueden competir y dejar auditoría inconsistente o duplicada.
- **No valida transición:** cualquier estado distinto de cerrado podría terminar en `PROCESADA`, si existe aprobación.

### A2.3 Corrección propuesta

Ver `sql/A2-cerrar-solicitud-corregido.sql`.

Decisiones:

- `SELECT ... FOR UPDATE` obtiene y bloquea la solicitud antes de validar y modificar.
- `PROCESADA` es idempotente: la rutina no vuelve a actualizar ni genera otra auditoría.
- Bajo el supuesto funcional explícito del enunciado, solo `PENDIENTE` puede pasar a `PROCESADA`.
- Se comprueba que exista al menos una gestión aprobada.
- Se toma el estado anterior real desde la fila bloqueada.
- Se actualiza y se inserta auditoría sin `COMMIT` intermedio.
- Se define un `SAVEPOINT`; ante error se revierte lo hecho desde ese punto y se relanza la excepción.
- La transacción queda bajo control del llamador, que debe ejecutar `COMMIT` si todo el flujo terminó bien o `ROLLBACK` si no. Incluso en los retornos sin cambios (`PROCESADA` o sin aprobación), el bloqueo adquirido con `FOR UPDATE` se libera únicamente al finalizar la transacción; el llamador no debe dejar la sesión abierta.

### A2.4 Casos solicitados

| Caso | Comportamiento propuesto |
|---|---|
| `p_id` no existe | `RAISE_APPLICATION_ERROR(-20001, ...)`; no modifica datos. |
| Ya está `PROCESADA` | Retorna sin duplicar actualización ni auditoría. |
| No existe gestión `APROBADA` | Retorna sin modificar estado ni auditoría. La fila queda bloqueada hasta que el llamador cierre la transacción; debe finalizarla pronto. |
| Estado distinto de `PENDIENTE` y `PROCESADA` | Rechaza transición con error funcional; confirmar catálogo de estados con negocio. |
| Falla el INSERT de auditoría | `ROLLBACK TO SAVEPOINT` revierte la actualización; la excepción se propaga. |

### A2.5 Validación

Probar en una base de desarrollo con solicitud de cada caso. Para demostrar atomicidad, provocar controladamente un error al insertar auditoría (por ejemplo, constraint o trigger de prueba) y comprobar que `SOLICITUD.estado` permanece igual al valor anterior. Ejecutar dos sesiones intentando cerrar el mismo `id_solicitud`; la segunda debe esperar el bloqueo y luego encontrar `PROCESADA`, sin insertar auditoría duplicada.

## A3. Diagnóstico y corrección controlada

### Criterio de selección

Candidato: solicitud con `estado = 'PROCESADA'` para la que no existe ninguna fila en `GESTION` con `resultado = 'APROBADA'`. Se usa `NOT EXISTS` para no multiplicar filas. Este criterio identifica **posibles inconsistencias**, no demuestra que cada caso sea incorrecto: podría existir una fuente de aprobación no contemplada en el modelo o un problema histórico de carga.

### Corrección propuesta

Ver `sql/A3-diagnostico-correccion-controlada.sql`.

- La primera consulta muestra `id_solicitud`, documento, estado, fechas y cantidad de gestiones.
- El bloque correctivo está protegido por `v_confirmar_correccion := FALSE`.
- Para activarlo se requiere revisión del listado, autorización funcional y confirmar que `PENDIENTE` es el estado correcto de reversa.
- Por cada candidato revalida que siga `PROCESADA` y que no exista gestión aprobada, bloquea su fila, actualiza a `PENDIENTE` e inserta auditoría con estado anterior y nuevo.
- No ejecuta `COMMIT`. Permite revisar en la misma sesión y decidir `COMMIT` o `ROLLBACK`.
- Si cualquier auditoría falla, el bloque hace rollback al savepoint y relanza el error.

### Verificación y contingencia

Después del bloque, volver a ejecutar la consulta de candidatos: el resultado esperado para los registros corregidos es que ya no aparezcan en el conjunto `PROCESADA` sin aprobación. Revisar además las nuevas filas de `AUDITORIA_SOLICITUD` y comparar cantidad de filas actualizadas y auditadas.

Antes de confirmar, `ROLLBACK` restaura tanto la actualización como las auditorías del bloque. Después de un `COMMIT`, no se deben borrar auditorías ni reescribir historia: una reversa exige revisión manual, una nueva transición compensatoria y una nueva fila de auditoría que explique la causa. Conservar el listado exportado de IDs y el identificador/fecha de la ejecución como evidencia del cambio.

## B1. Lectura y corrección Java

### Qué hace el método original

Busca la solicitud por ID, obtiene el nombre del cliente, carga las gestiones y toma el primer elemento para construir el DTO.

### Por qué falla y fragilidades

1. El repositorio puede devolver `Optional.empty()`; `orElse(null)` convierte esa ausencia en `null` y `solicitud.getCliente()` provoca exactamente el NPE observado en el log.
2. `solicitud.getCliente()` puede ser `null` si la relación no existe o no fue cargada; `getNombre()` también puede ser `null`, por lo que `trim()` puede fallar.
3. `gestiones.get(0)` falla si la lista está vacía (`IndexOutOfBoundsException`).
4. El primer elemento no necesariamente es la gestión más reciente si la consulta no declara un orden.
5. No existe una política explícita para una solicitud sin gestiones ni para un cliente sin nombre.

### Corrección

El código en `java/src/main/java` reemplaza `orElse(null)` por una excepción de dominio explícita, trata el cliente/nombre ausente y calcula la fecha máxima entre las gestiones recibidas sin confiar en su orden. Cuando no hay gestiones, el DTO contiene `null` en `ultimaFechaGestion`; esta semántica debe alinearse con el contrato del API real.

**Integración Spring:** mapear `SolicitudNotFoundException` a HTTP 404 mediante `@ControllerAdvice`. Los errores inesperados deben responder 500 con mensaje genérico y un identificador de correlación, mientras el log interno conserva stack trace y contexto técnico no sensible.

### Logs: incluir / evitar

| Incluir | Evitar |
|---|---|
| Correlation ID / trace ID | Documento completo del cliente |
| ID técnico de solicitud, si la política lo permite | Nombre, datos personales o contenido de la solicitud |
| Operación, repositorio/etapa y resultado | Tokens, cookies, credenciales o cabeceras de autorización |
| Tipo de excepción y stack trace interno | SQL con datos sensibles o payloads completos |
| Duración y código de resultado | Devolver stack trace, rutas internas o detalles de BD al consumidor |

## B2. Verificación

Los casos automatizados están en `java/src/test`. El diseño esperado es:

- solicitud existente con varias gestiones desordenadas: DTO contiene la fecha máxima;
- solicitud inexistente: lanza `SolicitudNotFoundException` en lugar de NPE;
- solicitud sin gestiones: DTO se genera con fecha de última gestión `null`;
- solicitud con cliente nulo o nombre nulo: consulta no falla y el nombre del DTO queda `null`;
- gestión con fecha nula: se ignora para calcular el máximo.

Ver también `docs/02-validacion-y-pruebas.md`.
