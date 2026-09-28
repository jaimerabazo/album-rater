-- Pruebas de permisos con dos cuentas ficticias. Todo se revierte al terminar.
-- Ejecutar en una base de desarrollo, después de aplicar la migración.
begin;

create function pg_temp.assert_true(ok boolean, label text) returns void
language plpgsql as $$
begin
    if ok is distinct from true then raise exception 'FAIL: %', label; end if;
end;
$$;

create function pg_temp.expect_error(statement text, expected_code text) returns void
language plpgsql as $$
begin
    begin
        execute statement;
    exception when others then
        if sqlstate = expected_code then return; end if;
        raise;
    end;
    raise exception 'FAIL: se esperaba SQLSTATE %: %', expected_code, statement;
end;
$$;

insert into auth.users (id) values
('f1000000-0000-4000-8000-000000000001'),
('f1000000-0000-4000-8000-000000000002');

set local role authenticated;
select set_config('request.jwt.claim.sub', 'f1000000-0000-4000-8000-000000000001', true);
insert into public.profiles (id, username, display_name)
values ('f1000000-0000-4000-8000-000000000001', 'test_profile_a', 'Persona A');
select pg_temp.assert_true((select count(*) = 1 from public.profiles), 'leer el propio perfil');
select pg_temp.assert_true((select created_at is not null from public.profiles), 'fecha del servidor');
select pg_temp.expect_error($q$insert into public.profiles (id, username, display_name)
values ('f1000000-0000-4000-8000-000000000002', 'fake_b', 'Ajeno')$q$, '42501');
select pg_temp.expect_error($q$update public.profiles set id = 'f1000000-0000-4000-8000-000000000002'$q$, '42501');
select pg_temp.expect_error($q$update public.profiles set created_at = now()$q$, '42501');
select pg_temp.expect_error('delete from public.profiles', '42501');
select pg_temp.expect_error($q$update public.profiles set username = 'MAYUSCULAS'$q$, '23514');
select pg_temp.expect_error($q$update public.profiles set username = 'ab'$q$, '23514');
select pg_temp.expect_error($q$update public.profiles set username = repeat('a', 31)$q$, '23514');
select pg_temp.expect_error($q$update public.profiles set username = 'con espacio'$q$, '23514');
select pg_temp.expect_error($q$update public.profiles set username = null$q$, '23502');
select pg_temp.expect_error($q$update public.profiles set display_name = ' '$q$, '23514');
select pg_temp.expect_error($q$update public.profiles set display_name = repeat('a', 51)$q$, '23514');
select pg_temp.expect_error($q$update public.profiles set display_name = E'Nombre\nOtro'$q$, '23514');
update public.profiles set display_name = 'Nombre actualizado';
select pg_temp.assert_true((select display_name = 'Nombre actualizado' from public.profiles), 'editar el propio perfil');

select set_config('request.jwt.claim.sub', 'f1000000-0000-4000-8000-000000000002', true);
select pg_temp.assert_true((select count(*) = 0 from public.profiles), 'B no puede leer A');
select pg_temp.expect_error($q$insert into public.profiles (id, username, display_name)
values ('f1000000-0000-4000-8000-000000000002', 'test_profile_a', 'Persona B')$q$, '23505');
insert into public.profiles (id, username, display_name)
values ('f1000000-0000-4000-8000-000000000002', 'test_profile_b', 'Persona B');
with changed as (
 update public.profiles set display_name = 'Intento ajeno'
 where id = 'f1000000-0000-4000-8000-000000000001' returning id
) select pg_temp.assert_true((select count(*) = 0 from changed), 'B no puede actualizar A');
select pg_temp.assert_true((select count(*) = 1 from public.profiles), 'B solo ve su perfil');
select pg_temp.expect_error($q$insert into public.profiles (id, username, display_name)
values ('f1000000-0000-4000-8000-000000000002', 'otro_nombre', 'Duplicado')$q$, '23505');

set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select pg_temp.expect_error('select * from public.profiles', '42501');
select pg_temp.expect_error($q$insert into public.profiles (id, username, display_name)
values ('f1000000-0000-4000-8000-000000000003', 'sin_sesion', 'Anónimo')$q$, '42501');
select pg_temp.expect_error($q$update public.profiles set display_name = 'Anónimo'$q$, '42501');
select pg_temp.expect_error('delete from public.profiles', '42501');

reset role;
select pg_temp.expect_error($q$insert into public.profiles (id, username, display_name)
values ('f1000000-0000-4000-8000-000000000003', 'sin_cuenta', 'Inválido')$q$, '23503');
select pg_temp.assert_true((select display_name = 'Nombre actualizado' from public.profiles
where id = 'f1000000-0000-4000-8000-000000000001'), 'A permanece intacto');
delete from auth.users where id = 'f1000000-0000-4000-8000-000000000001';
select pg_temp.assert_true(not exists(select 1 from public.profiles where id =
'f1000000-0000-4000-8000-000000000001'), 'borrado en cascada del perfil');

rollback;
select 'PASS: permisos, restricciones y borrado en cascada' as result;
