## Qué cambia y por qué

<!-- Una o dos frases. Si cierra un requisito, cita su ID (RF-00X / RNF-00X). -->

## Cómo se ha probado

- [ ] El CI está en verde (base de datos, paquete Swift y app).
- [ ] Si cambian pantallas o el flujo: `scripts/test-ui.sh` pasa en local.
- [ ] Si hay migración: es un fichero nuevo en `supabase/migrations`, con tests en `supabase/tests/database`.
- [ ] Si hay migración: aplicada en el proyecto de Supabase después de fusionar, y anotada en `supabase/README.md`.

## Notas para revisar

<!-- Decisiones, riesgos o capturas. -->
