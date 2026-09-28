-- RF-005, RF-006, RNF-001, RNF-003
-- Una cuenta puede tener un perfil. No creamos ni modificamos auth.users.
begin;

create table public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    username text not null,
    display_name text not null,
    created_at timestamptz not null default now(),

    constraint profiles_username_key unique (username),
    -- Solo se almacenan usernames normalizados, sin espacios ni mayúsculas.
    constraint profiles_username_format check (
        username ~ '^[a-z0-9_]{3,30}$'
    ),
    constraint profiles_display_name_format check (
        char_length(display_name) between 1 and 50
        and display_name = btrim(display_name)
        and display_name !~ '^[[:space:]]|[[:space:]]$'
        and display_name !~ '[[:cntrl:]]'
    )
);

alter table public.profiles enable row level security;

-- Quitamos los permisos amplios que pudiera heredar una tabla nueva.
revoke all on table public.profiles from public, anon, authenticated;

-- Se puede leer el perfil propio y escribir sus datos, pero no cambiar
-- el identificador, falsificar created_at ni borrar perfiles desde la app.
grant select on table public.profiles to authenticated;
grant insert (id, username, display_name) on public.profiles to authenticated;
grant update (username, display_name) on public.profiles to authenticated;

create policy profiles_select_own
    on public.profiles for select to authenticated
    using ((select auth.uid()) = id);

create policy profiles_insert_own
    on public.profiles for insert to authenticated
    with check ((select auth.uid()) = id);

create policy profiles_update_own
    on public.profiles for update to authenticated
    using ((select auth.uid()) = id)
    with check ((select auth.uid()) = id);

commit;
