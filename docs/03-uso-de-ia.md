# 3. Registro de uso de herramientas de IA

La prueba permite el uso de IA siempre que se documente su intervención y se valide el resultado.

| Actividad | Apoyo recibido | Resultado incorporado | Verificación / corrección humana |
|---|---|---|---|
| Interpretación del enunciado | Organización de requisitos A1, A2, A3, B1 y B2 | Estructura de carpetas y matriz de entregables | Contrastado con las páginas 1–5 del PDF de la prueba. |
| Diagnóstico SQL | Identificación de predicados no sargables, agregación y plan de ejecución | Consulta reescrita y plan de medición | Se documentaron supuestos de normalización y se indicó que el plan debe medirse en Oracle. |
| PL/SQL | Revisión de límites transaccionales, bloqueo y propagación de errores | Procedimiento con `FOR UPDATE`, savepoint y auditoría dentro de la transacción | Se revisó que no exista `COMMIT` interno y que el error haga rollback y se relance. |
| Corrección controlada | Diseño de previsualización, guardia de activación y validación posterior | Script A3 desactivado por defecto | Se dejó `v_confirmar_correccion := FALSE`; requiere aprobación y confirmación del estado destino. |
| Java | Refactor de null handling y selección de última fecha | Servicio Java aislado y pruebas | Compilación y ejecución local con JDK mediante `run-tests.sh`. |
| Documentación | Organización de decisiones, riesgos y plan de pruebas | README y documentos de soporte | Se separaron hechos del enunciado, inferencias y supuestos. |

## Resultados descartados o sujetos a evidencia

- No se afirma que `EXISTS` siempre sea más rápido que `IN`; el optimizador puede transformar ambos.
- No se recomienda crear índices adicionales sin comparar planes y carga.
- No se asume que la ausencia de una gestión aprobada demuestra por sí sola que una solicitud PROCESADA sea errónea.
- No se realiza `COMMIT` desde el procedimiento ni desde el script correctivo.
- No se afirma que la integración Java con Spring/JPA esté probada, porque el proyecto fuente no fue entregado.

No se incluyeron datos personales, credenciales ni secretos en las consultas o en el repositorio.
