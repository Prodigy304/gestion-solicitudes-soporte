# 4. Estado de la entrega y limitaciones

## Estado de la entrega

La solución fue publicada en un repositorio público de GitHub:

- Repositorio: https://github.com/Prodigy304/gestion-solicitudes-soporte
- Rama: main
- Tiempo total registrado: 106.6 minutos de un presupuesto de 120 minutos.
- Pruebas Java: 5 pruebas superadas mediante ejecución local.

El repositorio contiene los scripts SQL/PLSQL, la implementación Java, las pruebas automatizadas y la documentación técnica de las decisiones adoptadas.

## Validaciones realizadas

- Se ejecutaron las cinco pruebas Java mediante el JDK.
- Se verificó el formato de los archivos con `git diff --check`.
- Se realizó una revisión básica para detectar posibles secretos.
- Se publicó la rama main en GitHub.
- Se verificó que la rama local estuviera sincronizada con `origin/main` y que el árbol de trabajo estuviera limpio.

## Limitaciones técnicas

La solución se elaboró a partir del enunciado de la prueba. No se proporcionaron el esquema DDL completo de Oracle, los datos de producción, los planes de ejecución reales ni el código fuente de la aplicación Spring/JPA.

Por esta razón:

- La optimización SQL es una propuesta que requiere medición en Oracle antes de su implementación productiva.
- Los procedimientos PL/SQL deben validarse contra el esquema real y las reglas de negocio.
- La corrección A3 permanece desactivada por defecto y requiere aprobación funcional antes de ejecutarse.
- La implementación Java y sus pruebas verifican la lógica de servicio de manera aislada; no constituyen pruebas de integración con Spring/JPA.

Los supuestos funcionales y técnicos se encuentran documentados en `01-diagnostico-y-decisiones.md`.
