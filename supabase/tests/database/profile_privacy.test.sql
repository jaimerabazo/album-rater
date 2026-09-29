-- M3.1 (RF-012): perfil público o privado. Ejecutar con `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

insert into auth.users (id) values
('f3000000-0000-4000-8000-000000000001'),
('f3000000-0000-4000-8000-000000000002');

-- A crea su perfil sin indicar privacidad.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'f3000000-0000-4000-8000-000000000001', true);
insert into public.profiles (id, username, display_name)
values ('f3000000-0000-4000-8000-000000000001', 'privacy_a', 'Persona A');
select is((select is_private from public.profiles), false, 'un perfil nuevo es público (D-005)');

select lives_ok($$update public.profiles set is_private = true$$, 'A pasa su perfil a privado');
select is((select is_private from public.profiles), true, 'el cambio se guarda');
select lives_ok($$update public.profiles set is_private = false$$, 'A vuelve a público');
select throws_ok($$update public.profiles set is_private = null$$, '23502', null, 'la privacidad es obligatoria');

-- B no puede cambiar la privacidad de A.
select set_config('request.jwt.claim.sub', 'f3000000-0000-4000-8000-000000000002', true);
with changed as (
    update public.profiles set is_private = true
    where id = 'f3000000-0000-4000-8000-000000000001' returning id
) select is(count(*), 0::bigint, 'B no cambia la privacidad de A') from changed;

-- Sin sesión, tampoco.
set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select throws_ok($$update public.profiles set is_private = true$$, '42501', null, 'sin sesión no se cambia');

select * from finish();
rollback;
