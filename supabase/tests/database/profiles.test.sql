-- Permisos y restricciones de public.profiles (RF-005, RF-006, RNF-001, RNF-003).
-- Ejecutar con `supabase test db`. Todo ocurre en una transacción que se revierte.
begin;
create extension if not exists pgtap with schema extensions;
select plan(32);

select ok((select relrowsecurity from pg_class where oid = 'public.profiles'::regclass), 'RLS activado');

insert into auth.users (id) values
('f1000000-0000-4000-8000-000000000001'),
('f1000000-0000-4000-8000-000000000002');

-- Cuenta A
set local role authenticated;
select set_config('request.jwt.claim.sub', 'f1000000-0000-4000-8000-000000000001', true);
select lives_ok($$insert into public.profiles (id, username, display_name)
    values ('f1000000-0000-4000-8000-000000000001', 'test_profile_a', 'Persona A')$$, 'A crea su perfil');
select is((select count(*) from public.profiles), 1::bigint, 'A lee su perfil');
select ok((select created_at is not null from public.profiles), 'created_at lo asigna el servidor');
select throws_ok($$insert into public.profiles (id, username, display_name)
    values ('f1000000-0000-4000-8000-000000000002', 'fake_b', 'Ajeno')$$, '42501', null, 'A no crea el perfil de B');
select throws_ok($$update public.profiles set id = 'f1000000-0000-4000-8000-000000000002'$$,
    '42501', null, 'el id no se puede cambiar');
select throws_ok($$update public.profiles set created_at = now()$$, '42501', null, 'created_at no se puede cambiar');
select throws_ok('delete from public.profiles', '42501', null, 'el perfil no se borra desde la app');
select throws_ok($$update public.profiles set username = 'MAYUSCULAS'$$, '23514', null, 'username en minúsculas');
select throws_ok($$update public.profiles set username = 'ab'$$, '23514', null, 'username de 3 caracteres o más');
select throws_ok($$update public.profiles set username = repeat('a', 31)$$, '23514', null, 'username de 30 caracteres o menos');
select throws_ok($$update public.profiles set username = 'con espacio'$$, '23514', null, 'username sin espacios');
select throws_ok($$update public.profiles set username = null$$, '23502', null, 'username obligatorio');
select throws_ok($$update public.profiles set display_name = ' '$$, '23514', null, 'nombre visible no vacío');
select throws_ok($$update public.profiles set display_name = repeat('a', 51)$$, '23514', null, 'nombre visible de 50 caracteres o menos');
select throws_ok($$update public.profiles set display_name = E'Nombre\nOtro'$$, '23514', null, 'nombre visible sin saltos de línea');
select lives_ok($$update public.profiles set display_name = 'Nombre actualizado'$$, 'A edita su nombre visible');
select is((select display_name from public.profiles), 'Nombre actualizado', 'la edición se guarda');

-- Cuenta B
select set_config('request.jwt.claim.sub', 'f1000000-0000-4000-8000-000000000002', true);
select is((select count(*) from public.profiles), 0::bigint, 'B no lee el perfil de A');
select throws_ok($$insert into public.profiles (id, username, display_name)
    values ('f1000000-0000-4000-8000-000000000002', 'test_profile_a', 'Persona B')$$, '23505', null, 'username único');
select lives_ok($$insert into public.profiles (id, username, display_name)
    values ('f1000000-0000-4000-8000-000000000002', 'test_profile_b', 'Persona B')$$, 'B crea su perfil');
with changed as (
    update public.profiles set display_name = 'Intento ajeno'
    where id = 'f1000000-0000-4000-8000-000000000001' returning id
) select is(count(*), 0::bigint, 'B no edita el perfil de A') from changed;
select is((select count(*) from public.profiles), 1::bigint, 'B solo ve su perfil');
select throws_ok($$insert into public.profiles (id, username, display_name)
    values ('f1000000-0000-4000-8000-000000000002', 'otro_nombre', 'Duplicado')$$, '23505', null, 'un perfil por cuenta');

-- Sin sesión
set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select throws_ok('select * from public.profiles', '42501', null, 'sin sesión no se lee');
select throws_ok($$insert into public.profiles (id, username, display_name)
    values ('f1000000-0000-4000-8000-000000000003', 'sin_sesion', 'Anónimo')$$, '42501', null, 'sin sesión no se crea');
select throws_ok($$update public.profiles set display_name = 'Anónimo'$$, '42501', null, 'sin sesión no se edita');
select throws_ok('delete from public.profiles', '42501', null, 'sin sesión no se borra');

-- Integridad
reset role;
select throws_ok($$insert into public.profiles (id, username, display_name)
    values ('f1000000-0000-4000-8000-000000000003', 'sin_cuenta', 'Inválido')$$, '23503', null, 'no hay perfil sin cuenta');
select is((select display_name from public.profiles where id = 'f1000000-0000-4000-8000-000000000001'),
    'Nombre actualizado', 'el perfil de A sigue intacto');
delete from auth.users where id = 'f1000000-0000-4000-8000-000000000001';
select ok(not exists(select 1 from public.profiles where id = 'f1000000-0000-4000-8000-000000000001'),
    'borrar la cuenta borra su perfil');
select ok(exists(select 1 from public.profiles where id = 'f1000000-0000-4000-8000-000000000002'),
    'los demás perfiles no se tocan');

select * from finish();
rollback;
