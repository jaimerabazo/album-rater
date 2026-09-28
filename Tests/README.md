# Pruebas de perfiles

`ProfileTests.swift` comprueba validación, carga y guardado, errores, reintentos
y bloqueo de envíos duplicados con un repositorio de prueba. No contacta con Supabase.

En un Mac con Xcode:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc \
  -module-cache-path /private/tmp/album-rater-swift-cache \
  -parse-as-library AlbumRater/Profile.swift AlbumRater/ProfileStore.swift \
  Tests/ProfileTests.swift -o /private/tmp/album-rater-profile-tests
/private/tmp/album-rater-profile-tests
```

Las pruebas de permisos de PostgreSQL están en `supabase/tests/profiles.sql`.

Prueba manual pendiente en iPhone:

1. Iniciar sesión con tu cuenta existente: aparece Completa tu perfil.
2. Guardar nombre visible y username; aparecen los datos devueltos por el servidor.
3. Cerrar sesión y volver a entrar: se recupera el perfil sin volver a pedirlo.
4. Usar otra cuenta e intentar el mismo username: se muestra un aviso y conserva el formulario.
5. Cambiar de cuenta: nunca aparece el perfil anterior.
6. Desconectar la red al guardar y reintentar: no se muestra éxito sin confirmación
   ni se sobrescribe un perfil existente si la respuesta anterior se perdió.
