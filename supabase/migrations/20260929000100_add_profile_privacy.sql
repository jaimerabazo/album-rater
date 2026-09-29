-- M3.1 (RF-012): cada perfil puede ser público o privado.
-- D-005: los perfiles son públicos por defecto, también los que ya existen.
begin;

alter table public.profiles
    add column is_private boolean not null default false;

-- Cada persona puede cambiar la privacidad de su propio perfil. La política
-- profiles_update_own ya limita la edición al perfil propio.
grant update (is_private) on public.profiles to authenticated;

commit;
