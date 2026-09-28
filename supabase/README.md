# Migraciones de Album Rater

## Perfiles

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

## Reviews individuales

La migración `migrations/20260928000100_create_solo_reviews.sql` crea:

1. **listening_sessions**: un álbum escuchado en una ocasión (título, artista, propietario, fecha).
2. **session_tracks**: sus canciones en orden. No se editan; borrar la sesión las borra.
3. **track_ratings**: una nota por persona y canción, de 1 a 10 con un decimal como máximo,
   y un comentario opcional de hasta 1000 caracteres. `numeric` sin precisión fija hace que
   8,25 se rechace en lugar de redondearse en silencio.
4. **create_listening_session**: crea la sesión y sus canciones en una sola transacción.
   La app envía el id para que un reintento no duplique el álbum.
5. **set_track_rating**: guarda o sustituye la nota propia de una canción.

La media del álbum **no se guarda**: la app la calcula con las canciones puntuadas.
`owner_id` y `user_id` los asigna `auth.uid()`; la app no puede elegirlos. Las funciones
usan `security invoker`, así que aplican los mismos permisos y políticas que una consulta directa.
`user_id` en `track_ratings` prepara el milestone 3: al compartir sesiones, las políticas
cambiarán de «propietario» a «participante».

### Aplicación

En **SQL Editor**, pega el contenido completo de la migración y ejecútalo una sola vez,
después de la de perfiles. Luego ejecuta `tests/reviews.sql`: debe terminar con
`PASS: reviews, notas, permisos y borrados en cascada` y no conserva datos de prueba.

Registro de aplicación: pendiente.
