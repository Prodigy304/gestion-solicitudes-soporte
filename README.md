# Prueba técnica - Desarrollador de soporte

**Caso:** Gestión de Solicitudes
**Tecnologías:** Oracle SQL / PL/SQL y Java 21
**Versión del entregable:** 1.0
**Duración objetivo:** 120 minutos

## 1. Objetivo

Resolver la prueba desde el enfoque de soporte de segundo nivel: analizar la evidencia disponible, identificar causas probables, proponer cambios acotados y describir cómo validarlos antes de producción.

La solución sigue los apartados A1, A2, A3, B1 y B2 del enunciado. No se incluyen datos reales de clientes ni credenciales.

## 2. Estructura

```text
.
├── README.md
├── TIME_LOG.csv
├── docs/
│   ├── 01-diagnostico-y-decisiones.md
│   ├── 02-validacion-y-pruebas.md
│   ├── 03-uso-de-ia.md
│   └── 04-entrega-y-limitaciones.md
├── sql/
│   ├── A1-consulta-optimizada.sql
│   ├── A1-plan-ejecucion.sql
│   ├── A2-cerrar-solicitud-corregido.sql
│   └── A3-diagnostico-correccion-controlada.sql
├── java/
│   ├── README.md
│   ├── run-tests.sh
│   └── src/
│       ├── main/java/co/ias/soporte/...
│       └── test/java/co/ias/soporte/...
└── scripts/
    └── preparar-entrega.sh
```

## 3. Resumen ejecutivo

- **A1:** la función `TRUNC` aplicada a `s.fecha_creacion` dificulta el uso directo del índice convencional sobre esa columna. Se propone un predicado por rango de fechas, una agregación de gestiones limitada al conjunto filtrado y una evaluación empírica de un índice compuesto para `GESTION`.
- **A2:** el procedimiento original confirma la actualización antes de insertar auditoría y oculta cualquier excepción. La propuesta bloquea la fila, valida la transición, registra auditoría en la misma transacción y propaga errores.
- **A3:** se separa la consulta de previsualización de la corrección. El bloque correctivo queda desactivado por defecto y no ejecuta `COMMIT`.
- **B1:** se elimina el uso de `orElse(null)` seguido de desreferenciación, se maneja la ausencia de cliente y se calcula la fecha máxima de gestión sin depender del orden de la lista.
- **B2:** se incluye un pequeño arnés Java ejecutable con `javac` para verificar los escenarios solicitados y casos de borde.

## 4. Cómo ejecutar las pruebas Java

Requiere JDK 21 o compatible y `bash`:

```bash
cd java
./run-tests.sh
```

El arnés usa únicamente el JDK, sin dependencias externas. No es una prueba de integración Spring/JPA: verifica la lógica corregida aislada mediante repositorios falsos.

## 5. Cómo revisar los scripts SQL

Los scripts están escritos para Oracle SQL/PLSQL. Deben revisarse en una sesión no productiva y adaptarse si el DDL real difiere. No ejecutar A3 en producción sin aprobación, respaldo, revisión del listado de candidatos y ventana de cambio.

Orden recomendado:

1. Leer `docs/01-diagnostico-y-decisiones.md`.
2. Ejecutar únicamente las consultas de diagnóstico de `sql/A1-plan-ejecucion.sql` y la previsualización inicial de `sql/A3-diagnostico-correccion-controlada.sql` en un ambiente autorizado.
3. Validar `A2` en una transacción de prueba, incluyendo el fallo inducido de auditoría.
4. Revisar la corrección A3 con el responsable funcional. El interruptor `v_confirmar_correccion` está en `FALSE` de forma intencional.
5. Ejecutar `java/run-tests.sh`.

## 6. Supuestos que deben confirmarse

El documento de la prueba muestra los nombres y campos relevantes, pero no entrega DDL, restricciones, tipos exactos, volúmenes por estado, planes reales ni entidades Java completas. Por tanto:

- Se asume que `SOLICITUD.estado` usa valores canónicos en mayúsculas. Si no es así, debe conservarse la comparación insensible a mayúsculas y estudiar una normalización o índice basado en función.
- Para A2/A3 se asume que la transición admitida por el negocio es `PENDIENTE` → `PROCESADA` y que volver a `PENDIENTE` es la reversa autorizada para los candidatos confirmados. Esta regla requiere validación funcional antes de ejecutarse.
- Se asume que `SEQ_AUDITORIA` existe y que `AUDITORIA_SOLICITUD.id` se alimenta de esa secuencia, como sugiere el procedimiento original.
- En Java se usan `Long` para el identificador y `LocalDateTime` para la fecha de gestión. Deben ajustarse a los tipos reales del proyecto.
- La solución Java es una capa de servicio aislada. La integración con Spring, transacciones, controlador HTTP y repositorios JPA depende del proyecto real, que no fue adjuntado.

## 7. Gestión de la entrega

- El presupuesto por bloque está en `TIME_LOG.csv` y suma 120 minutos. Los tiempos reales se deben completar con las horas efectivamente trabajadas; no se registran tiempos ficticios.
- Antes de publicar: revisar `docs/04-entrega-y-limitaciones.md`, configurar la identidad Git propia y verificar que no haya datos sensibles.
- La URL pública, rama y hash final deben copiarse de la salida real de Git; no se deben inventar.

## 8. Referencia

Solución elaborada a partir de `02_Prueba_Tecnica_Desarrollador_Soporte_Candidato.pdf`, versión 1.0, noviembre de 2026. Los números de apartados y requisitos se mantienen alineados con el enunciado.

## 9. Temporizador de 120 minutos

El seguimiento real se puede hacer desde la raíz del repositorio:

```bash
python3 scripts/time_tracker.py start
python3 scripts/time_tracker.py status
python3 scripts/time_tracker.py next A2
python3 scripts/time_tracker.py next A3
python3 scripts/time_tracker.py next B1
python3 scripts/time_tracker.py next B2
python3 scripts/time_tracker.py stop
```

`next` cierra el bloque actual y registra su tiempo real en `TIME_LOG.csv`. `status` muestra el total transcurrido y el tiempo restante del límite. El archivo `.time-tracker.json` es local y está excluido de Git.
