# 4. Checklist de entrega

## Antes de publicar

- [ ] Revisar el nombre del repositorio y su visibilidad pública.
- [ ] Configurar la identidad Git con nombre y correo propios.
- [ ] Ejecutar `cd java && ./run-tests.sh` y guardar el resultado.
- [ ] Revisar todos los scripts Oracle; no ejecutar A3 sin autorización.
- [ ] Confirmar que no haya secretos, tokens ni datos reales.
- [ ] Revisar `TIME_LOG.csv` y completar tiempos reales; presupuesto total: 120 minutos.
- [ ] Leer los supuestos funcionales sobre estados y reversa.
- [ ] Ejecutar `git status`, `git diff --check` y revisar el contenido completo.
- [ ] Crear el commit final y registrar su hash real.
- [ ] Verificar que el repositorio se pueda clonar públicamente.

## Crear repositorio remoto y publicar

Desde la carpeta raíz del proyecto, después de crear un repositorio vacío en GitHub:

```bash
git config user.name "TU NOMBRE"
git config user.email "TU CORREO DE GIT"
git add .
git commit -m "feat: resolver prueba tecnica de soporte"
git branch -M main
git remote add origin https://github.com/TU_USUARIO/gestion-solicitudes-soporte.git
git push -u origin main
```

Si ya existe `origin`, revisar con `git remote -v` antes de agregarlo. No incluir credenciales en el repositorio.

## Datos que deben enviarse en el correo

- URL pública real del repositorio.
- Rama evaluable (por ejemplo `main`, si esa fue la rama publicada).
- Hash real del commit final (`git rev-parse HEAD`).

## Limitaciones conocidas

El paquete contiene una solución propuesta basada únicamente en el enunciado. No tiene acceso al esquema Oracle, datos de producción, plan de ejecución real ni código fuente Spring/JPA. La prueba automatizada Java es local y aislada. Las decisiones que dependen del catálogo de estados o la reversa se han marcado para confirmación con negocio.
