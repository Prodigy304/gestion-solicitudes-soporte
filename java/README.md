# Corrección Java aislada

Se implementó una versión pequeña y compilable de la lógica de consulta del enunciado. No se recreó una aplicación Spring completa porque no se proporcionó el proyecto original ni sus entidades, contratos HTTP o mappings JPA.

## Ejecución

```bash
./run-tests.sh
```

Requisitos: JDK 21 (o compatible) y Bash. No necesita Maven, Spring ni dependencias externas.

## Decisiones

- La solicitud ausente produce `SolicitudNotFoundException`; en la integración REST debe mapearse a HTTP 404.
- Cliente ausente, nombre nulo/vacío o ausencia de gestiones se representan con `null` en los campos correspondientes del DTO. Confirmar este contrato con el API real.
- La fecha máxima se calcula sobre todas las gestiones no nulas, sin depender del orden devuelto por el repositorio.
- Las interfaces de repositorio representan las dependencias que en la aplicación real implementarían Spring Data/JPA.

## Adaptación al proyecto real

Ajustar nombres y tipos de entidades, getters, DTO y firma del método. En una aplicación Spring, usar `@Transactional(readOnly = true)` si corresponde al patrón existente, declarar el query ordenado por fecha y mapear `SolicitudNotFoundException` mediante `@RestControllerAdvice`. La configuración exacta depende de la versión y estructura del proyecto.
