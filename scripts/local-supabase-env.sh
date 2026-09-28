#!/usr/bin/env bash
# Exporta la URL y la clave publicable del Supabase local (`supabase start`) para los tests.
# Uso: source scripts/local-supabase-env.sh
# Son las claves de demostración del entorno local, no las de ningún proyecto real.

if ! supabase_status="$(supabase status -o env 2>/dev/null)"; then
    echo "Supabase local no está en marcha. Ejecuta: supabase start" >&2
    return 1 2>/dev/null || exit 1
fi

SUPABASE_TEST_URL="$(sed -n 's/^API_URL="\(.*\)"$/\1/p' <<<"$supabase_status")"
SUPABASE_TEST_PUBLISHABLE_KEY="$(sed -n 's/^PUBLISHABLE_KEY="\(.*\)"$/\1/p' <<<"$supabase_status")"
export SUPABASE_TEST_URL SUPABASE_TEST_PUBLISHABLE_KEY
