# Milestone 3 — Social y sesiones compartidas

Objetivo: dos personas que se siguen mutuamente pueden escuchar y puntuar un álbum juntas.
Para eso hacen falta tres cosas, en este orden: **encontrarse → seguirse → invitarse**.

Cada submilestone es una PR pequeña con sus tests y termina en algo que se puede probar
en el simulador. Los requisitos nuevos van en `docs/requisitos-album-rater.docx` (RF-012 en adelante).

Estado: ⬜ pendiente · 🟡 en curso · ✅ hecho

## Fase A — Encontrarse

| ID | Qué | Terminado cuando… | Estado |
| --- | --- | --- | --- |
| M3.1 | Perfil público o privado (interruptor en tu perfil) | Cambias el interruptor, cierras la app y se mantiene | ⬜ |
| M3.2 | Buscar usuarios por username | Buscas «ana» y aparece Ana, sin su email ni datos privados | ⬜ |
| M3.3 | Ver el perfil de otra persona | Tocas un resultado y ves su nombre, username y si es privado | ⬜ |

## Fase B — Seguirse

| ID | Qué | Terminado cuando… | Estado |
| --- | --- | --- | --- |
| M3.4 | Seguir a un perfil público y dejar de seguirlo | Sigues a Ana y su perfil muestra «Siguiendo» | ⬜ |
| M3.5 | Solicitud de seguimiento a un perfil privado: aceptar o rechazar | Ana es privada: recibe tu solicitud y no la sigues hasta que acepta | ⬜ |
| M3.6 | Listas de seguidores y seguidos, y marca de «os seguís mutuamente» | Ves quién te sigue y quién es mutual | ⬜ |

## Fase C — Qué ve cada uno

| ID | Qué | Terminado cuando… | Estado |
| --- | --- | --- | --- |
| M3.7 | Ver el historial de álbumes de otra persona según su privacidad | Privada y sin seguirla: no ves nada. Si la sigues: sí | ⬜ |

## Fase D — Sesiones juntos

| ID | Qué | Terminado cuando… | Estado |
| --- | --- | --- | --- |
| M3.8 | La base de datos admite varios miembros por sesión | Todo sigue funcionando igual (cambio interno) | ⬜ |
| M3.9 | Enviar una solicitud de sesión a un mutual | Ana ve tu solicitud en su bandeja; tú puedes cancelarla | ⬜ |
| M3.10 | Aceptar o rechazar la solicitud | Si acepta, el álbum aparece en el historial de los dos | ⬜ |
| M3.11 | Puntuar juntos: notas de cada uno, media de cada uno y del grupo | Los dos puntúan y cada uno ve el resultado | ⬜ |
| M3.12 | Casos límite: dejar de seguirse, pasar a privado, solicitudes caducadas | Sin ser mutuals no se pueden crear sesiones nuevas | ⬜ |

## Fuera de este milestone

- Notificaciones push.
- Ver las notas del otro en tiempo real (milestone 4).
- Bloquear y denunciar usuarios (obligatorio antes de publicar en la App Store).

## Decisiones

Cada decisión se toma justo antes del submilestone que la necesita.

| ID | Pregunta | Decisión | Fecha |
| --- | --- | --- | --- |
| D-005 | ¿Un perfil nuevo empieza público o privado? | **Público.** Cada persona puede pasarlo a privado. | 2026-09-29 |
