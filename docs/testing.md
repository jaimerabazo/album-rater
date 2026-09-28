# Pruebas

La app se prueba por capas, como es habitual en iOS: cada capa con el tipo de test que
mejor la cubre y con su propio criterio de éxito.

| Capa | Qué contiene | Tests | Criterio | Comando |
| --- | --- | --- | --- | --- |
| **Core** | `Packages/AlbumRaterKit/Sources/AlbumRaterCore`: modelos, validación, notas, media y stores | Unitarios (Swift Testing) con repositorios falsos | **≥ 95% de líneas, obligatorio** | `scripts/test-core.sh` |
| **Datos** | `Packages/AlbumRaterKit/Sources/AlbumRaterData`: repositorios de Supabase | Integración contra Supabase local | Todos en verde; cobertura informativa | `scripts/test-data.sh` |
| **Base de datos** | `supabase/migrations`: tablas, restricciones y RLS | pgTAP (`supabase/tests/database`) | Todos en verde | `supabase test db` |
| **UI** | `AlbumRater/`: vistas SwiftUI, arranque y login | XCUITest del recorrido crítico (`AlbumRaterUITests`) | Todos en verde | `scripts/test-ui.sh` |

La cobertura del 95% se exige solo en Core porque es donde vive la lógica. Las vistas se
comprueban con pocos tests de UI de alto valor; forzar un porcentaje sobre ellas produciría
tests que solo comprueban que un texto existe.

## Preparación (una vez)

1. Xcode 26 o posterior.
2. [Docker Desktop](https://www.docker.com/products/docker-desktop/) en marcha.
3. CLI de Supabase: `brew install supabase/tap/supabase`.
4. Supabase local, que aplica todas las migraciones sobre una base vacía:

   ```sh
   supabase start
   ```

   Usa las claves de demostración del entorno local y nunca tu proyecto real.
   `supabase stop` lo detiene. Studio queda en http://127.0.0.1:54323.

> **Proyecto dentro de iCloud Drive** (por ejemplo, en el Escritorio sincronizado):
> macOS añade atributos a los ficheros compilados y `codesign` los rechaza. Compila fuera:
> `export SWIFT_SCRATCH_PATH=~/Library/Caches/album-rater/AlbumRaterKit`.
> Mejor aún: mueve el repositorio fuera de iCloud, que tampoco es buen sitio para `.git`.

## Core: tests unitarios

```sh
scripts/test-core.sh                 # falla si la cobertura baja del 95%
MIN_COVERAGE=100 scripts/test-core.sh
```

También desde Xcode: abre `Packages/AlbumRaterKit/Package.swift` y pulsa ⌘U.
Los tests están en `Packages/AlbumRaterKit/Tests/AlbumRaterCoreTests`, agrupados por tema:
notas, validación, media, estado del perfil y del historial. `Fakes.swift` contiene los
repositorios en memoria.

## Datos: integración con Supabase local

```sh
scripts/test-data.sh
```

Cada test crea cuentas nuevas con email y contraseña aleatorios (en local no hay
confirmación por email) y comprueba los repositorios reales: guardar, leer, reintentos
sin duplicados, aislamiento entre cuentas y acceso sin sesión. Sin Supabase local, los
tests se omiten en lugar de fallar.

## Base de datos: pgTAP

```sh
supabase test db
```

Cada fichero de `supabase/tests/database` se ejecuta en una transacción que se revierte.
Simulan dos cuentas y un visitante sin sesión, y comprueban permisos, restricciones,
formatos, funciones y borrados en cascada.

## UI: recorrido crítico

```sh
scripts/test-ui.sh
SIMULATOR="iPhone 17" scripts/test-ui.sh
```

`CriticalFlowUITests` crea una cuenta, completa el perfil, añade un álbum, puntúa dos
canciones (la media pasa de 9 a 8,5), vuelve al historial y cierra sesión. También prueba
el error de contraseña incorrecta.

La app solo acepta el backend de pruebas en compilaciones Debug y hacia `localhost`.
Si recibe las variables de test pero no son válidas, muestra la pantalla de configuración:
nunca usa tu proyecto real ni tu sesión guardada.

## Prueba manual en iPhone

Lo que la automatización no cubre: el correo real de confirmación y recuperación,
el proyecto de Supabase de producción y el dispositivo físico.

1. Crear cuenta y confirmar con el código del email; recuperar la contraseña.
2. Iniciar sesión con tu cuenta y comprobar perfil, álbumes y notas.
3. Cortar la red al guardar y reintentar: sin guardados falsos ni duplicados.
4. Texto grande de accesibilidad y VoiceOver.
