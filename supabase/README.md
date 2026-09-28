# Perfiles de Album Rater

La migración `migrations/20260911000100_create_profiles.sql` crea una sola tabla:
`public.profiles`. No crea cuentas nuevas ni cambia la estructura de Supabase Auth.

## Qué hace cada parte

1. **CREATE TABLE** define las cuatro columnas y los límites del nombre y username.
2. **PRIMARY KEY y REFERENCES** conectan cada perfil con una cuenta existente.
3. **UNIQUE** impide que dos perfiles tengan el mismo username.
4. **ENABLE ROW LEVEL SECURITY** activa las reglas por usuario.
5. **REVOKE y GRANT** dejan únicamente los permisos necesarios. El usuario no puede
   elegir la fecha de creación, cambiar el UUID ni borrar el perfil directamente.
6. **CREATE POLICY** permite leer, insertar y actualizar únicamente el perfil propio.
7. **BEGIN y COMMIT** aplican el cambio completo en una transacción.

La app transforma el username a minúsculas y elimina espacios en los extremos.
La base solo acepta su forma final: 3–30 caracteres `a-z`, `0-9` o `_`.
No hay triggers que creen perfiles durante el registro. Tu cuenta existente verá
el formulario al iniciar sesión, y el perfil se creará cuando lo guardes.

## Aplicación en otro proyecto

Abre **SQL Editor**, pega el contenido completo de la migración y ejecútalo una
sola vez. No la vuelvas a ejecutar si `profiles` ya existe. Los cambios posteriores
se guardan en otro archivo de migración, sin reescribir uno ya aplicado.

Aplicar SQL desde el panel no registra automáticamente el archivo en el historial
de Supabase CLI. Si se adopta la CLI más adelante, hay que reconciliar esta migración
como ya aplicada antes de usar `db push` contra este proyecto; no intentar recrearla.

## Pruebas de permisos

`tests/profiles.sql` crea dos cuentas ficticias dentro de una transacción, comprueba
permisos y restricciones, y termina con `ROLLBACK`: no conserva datos de prueba.
Ejecutarlo en una base de desarrollo después de la migración. Si una sentencia
falla, ejecutar `ROLLBACK` en la misma conexión antes de continuar.

Incluye lectura/edición propia, aislamiento entre cuentas, acceso sin sesión,
username repetido, formato inválido, UUID repetido, cuenta inexistente, fecha e ID
no editables y borrado del perfil al borrar la cuenta.

Para probar de forma aislada, se ha usado PostgreSQL embebido (PGlite 0.3.14), con
una tabla auth.users mínima y una función auth.uid que toma el usuario simulado.
Eso verifica PostgreSQL y RLS; no sustituye la prueba de autenticación y guardado
en un iPhone conectado al proyecto real.

## Registro de aplicación y verificación

11 de septiembre de 2026, proyecto `album-rater` (`jexcksnhbmkwpqtqdymi`):

- Migración ejecutada desde SQL Editor: `Success. No rows returned.`
- Consulta de catálogo: `profiles` existe y `relrowsecurity = true`.
- `tests/profiles.sql` ejecutado en el proyecto: `PASS: permisos, restricciones y borrado en cascada`.
- La transacción de pruebas terminó con `ROLLBACK`; no conserva cuentas ni perfiles ficticios.
- Compilación de la app y pruebas de lógica Swift: correctas.
- Prueba completa desde el iPhone con la cuenta del usuario: pendiente.

El historial gestionado por Supabase CLI no se ha modificado. Este archivo registra
la aplicación manual del SQL que permanece versionado en el repositorio.
