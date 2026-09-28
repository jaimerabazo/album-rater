# Pruebas

Las pruebas usan repositorios de prueba y no contactan con Supabase.

- `ProfileTests.swift`: validación, carga y guardado, errores, reintentos y bloqueo
  de envíos duplicados del perfil.
- `ReviewTests.swift`: notas (1–10 con un decimal), cálculo de la media a medida que
  se puntúan canciones, validación de álbum y canciones, errores sin guardados falsos,
  reintentos sin duplicados y decodificación de la respuesta de Supabase.

En un Mac con Xcode:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc \
  -module-cache-path /private/tmp/album-rater-swift-cache \
  -parse-as-library AlbumRater/TextValidation.swift AlbumRater/Profile.swift \
  AlbumRater/ProfileStore.swift Tests/ProfileTests.swift -o /private/tmp/album-rater-profile-tests
/private/tmp/album-rater-profile-tests

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc \
  -module-cache-path /private/tmp/album-rater-swift-cache \
  -parse-as-library AlbumRater/TextValidation.swift AlbumRater/Review.swift \
  AlbumRater/ReviewsStore.swift Tests/ReviewTests.swift -o /private/tmp/album-rater-review-tests
/private/tmp/album-rater-review-tests
```

Las pruebas de permisos de PostgreSQL están en `supabase/tests/profiles.sql` y
`supabase/tests/reviews.sql`.

Prueba manual pendiente en iPhone:

1. Iniciar sesión con tu cuenta existente: aparece Completa tu perfil.
2. Guardar nombre visible y username; aparecen los datos devueltos por el servidor.
3. Cerrar sesión y volver a entrar: se recupera el perfil sin volver a pedirlo.
4. Usar otra cuenta e intentar el mismo username: se muestra un aviso y conserva el formulario.
5. Cambiar de cuenta: nunca aparece el perfil anterior.
6. Desconectar la red al guardar y reintentar: no se muestra éxito sin confirmación
   ni se sobrescribe un perfil existente si la respuesta anterior se perdió.

Prueba manual pendiente de las reviews:

1. Añadir un álbum con cinco canciones: se abre su detalle con la media «–».
2. Puntuar la primera con 9: la media pasa a 9. Puntuar la segunda con 8: pasa a 8,5.
3. Volver al historial: la fila muestra 8,5 y 2/5.
4. Cerrar sesión y volver a entrar: el álbum, las notas y los comentarios se recuperan.
5. Quitar una nota y borrar un álbum: la media y el historial se actualizan.
6. Con otra cuenta: el álbum no aparece.
