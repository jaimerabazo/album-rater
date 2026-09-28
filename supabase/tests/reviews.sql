-- Pruebas de permisos de las reviews con dos cuentas ficticias. Todo se revierte al terminar.
-- Ejecutar en una base de desarrollo, después de aplicar las migraciones.
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
('f2000000-0000-4000-8000-000000000001'),
('f2000000-0000-4000-8000-000000000002');

-- A crea un álbum con tres canciones.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'f2000000-0000-4000-8000-000000000001', true);
select pg_temp.assert_true(
    public.create_listening_session('a2000000-0000-4000-8000-00000000000a', 'Álbum A', 'Artista',
        array['Uno', 'Dos', 'Tres']) = 'a2000000-0000-4000-8000-00000000000a',
    'crear sesión devuelve su id');
select pg_temp.assert_true((select owner_id = 'f2000000-0000-4000-8000-000000000001'
    from public.listening_sessions), 'owner_id lo asigna el servidor');
select pg_temp.assert_true((select array_agg(title order by position) = array['Uno', 'Dos', 'Tres']
    from public.session_tracks), 'canciones en orden');

-- Reintento con el mismo id: no crea un duplicado.
select pg_temp.expect_error($q$select public.create_listening_session(
    'a2000000-0000-4000-8000-00000000000a', 'Álbum A', 'Artista', array['Uno'])$q$, '23505');
select pg_temp.assert_true((select count(*) = 3 from public.session_tracks), 'el reintento no añade canciones');

-- Validación: sin canciones, títulos vacíos o con saltos de línea.
select pg_temp.expect_error($q$select public.create_listening_session(gen_random_uuid(), 'X', 'Y', array[]::text[])$q$, '22023');
select pg_temp.expect_error($q$select public.create_listening_session(gen_random_uuid(), 'X', 'Y', null)$q$, '22023');
select pg_temp.expect_error($q$select public.create_listening_session(gen_random_uuid(), ' ', 'Y', array['a'])$q$, '23514');
select pg_temp.expect_error($q$select public.create_listening_session(gen_random_uuid(), 'X', 'Y', array['a', ''])$q$, '23514');
select pg_temp.expect_error($q$select public.create_listening_session(gen_random_uuid(), E'X\nZ', 'Y', array['a'])$q$, '23514');
select pg_temp.expect_error($q$select public.create_listening_session(gen_random_uuid(), 'X', 'Y', array_fill('a'::text, array[101]))$q$, '22023');
select pg_temp.assert_true((select count(*) = 1 from public.listening_sessions), 'los fallos no dejan sesiones a medias');

-- No se puede elegir el propietario ni editar canciones.
select pg_temp.expect_error($q$insert into public.listening_sessions (album_title, artist_name, owner_id)
values ('X', 'Y', 'f2000000-0000-4000-8000-000000000002')$q$, '42501');
select pg_temp.expect_error($q$update public.session_tracks set title = 'Otro'$q$, '42501');
select pg_temp.expect_error($q$update public.listening_sessions set album_title = 'Otro'$q$, '42501');

-- Notas: de 1 a 10 con un decimal como máximo.
create temp table ids as
select position, id from public.session_tracks order by position;
grant select on ids to authenticated, anon;
select public.set_track_rating((select id from ids where position = 1), 9, null);
select public.set_track_rating((select id from ids where position = 2), 8, 'Muy buena');
select pg_temp.assert_true((select avg(score) = 8.5 from public.track_ratings), 'media de las canciones puntuadas');
select public.set_track_rating((select id from ids where position = 2), 7.5, null);
select pg_temp.assert_true((select score = 7.5 and comment is null from public.track_ratings
    where track_id = (select id from ids where position = 2)), 'volver a puntuar sustituye nota y comentario');
select pg_temp.assert_true((select count(*) = 2 from public.track_ratings), 'una nota por canción');
select public.set_track_rating((select id from ids where position = 3), 1, null);
select public.set_track_rating((select id from ids where position = 3), 10, null);
select pg_temp.expect_error($q$select public.set_track_rating((select id from ids where position = 3), 0.9, null)$q$, '23514');
select pg_temp.expect_error($q$select public.set_track_rating((select id from ids where position = 3), 10.1, null)$q$, '23514');
select pg_temp.expect_error($q$select public.set_track_rating((select id from ids where position = 3), 8.25, null)$q$, '23514');
select pg_temp.expect_error($q$select public.set_track_rating((select id from ids where position = 3), null, null)$q$, '23502');
select pg_temp.expect_error($q$select public.set_track_rating((select id from ids where position = 3), 8, repeat('a', 1001))$q$, '23514');
select pg_temp.expect_error($q$select public.set_track_rating((select id from ids where position = 3), 8, ' ')$q$, '23514');
select pg_temp.expect_error($q$update public.track_ratings set user_id = 'f2000000-0000-4000-8000-000000000002'$q$, '42501');
select pg_temp.expect_error($q$update public.track_ratings set track_id = (select id from ids where position = 1)$q$, '42501');
delete from public.track_ratings where track_id = (select id from ids where position = 3);
select pg_temp.assert_true((select count(*) = 2 from public.track_ratings), 'quitar la nota propia');

-- B no ve ni modifica nada de A.
select set_config('request.jwt.claim.sub', 'f2000000-0000-4000-8000-000000000002', true);
select pg_temp.assert_true((select count(*) = 0 from public.listening_sessions), 'B no ve sesiones de A');
select pg_temp.assert_true((select count(*) = 0 from public.session_tracks), 'B no ve canciones de A');
select pg_temp.assert_true((select count(*) = 0 from public.track_ratings), 'B no ve notas de A');
select pg_temp.expect_error($q$insert into public.session_tracks (session_id, position, title)
values ('a2000000-0000-4000-8000-00000000000a', 4, 'Intrusa')$q$, '42501');
select pg_temp.expect_error($q$select public.set_track_rating((select id from ids where position = 3), 5, null)$q$, '42501');
with removed as (
    delete from public.listening_sessions where id = 'a2000000-0000-4000-8000-00000000000a' returning id
) select pg_temp.assert_true((select count(*) = 0 from removed), 'B no puede borrar la sesión de A');
with removed as (
    delete from public.track_ratings returning track_id
) select pg_temp.assert_true((select count(*) = 0 from removed), 'B no puede borrar notas de A');
-- B no puede reutilizar el id de la sesión de A.
select pg_temp.expect_error($q$select public.create_listening_session(
    'a2000000-0000-4000-8000-00000000000a', 'Mío', 'Artista', array['Uno'])$q$, '23505');
select public.create_listening_session('b2000000-0000-4000-8000-00000000000b', 'Álbum B', 'Artista', array['Uno']);
select pg_temp.assert_true((select count(*) = 1 from public.listening_sessions), 'B solo ve su sesión');

-- Sin sesión no hay acceso.
set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select pg_temp.expect_error('select * from public.listening_sessions', '42501');
select pg_temp.expect_error('select * from public.session_tracks', '42501');
select pg_temp.expect_error('select * from public.track_ratings', '42501');
select pg_temp.expect_error($q$select public.create_listening_session(gen_random_uuid(), 'X', 'Y', array['a'])$q$, '42501');
select pg_temp.expect_error($q$select public.set_track_rating((select id from ids where position = 1), 5, null)$q$, '42501');

-- Borrados en cascada.
reset role;
select pg_temp.assert_true((select score = 9 from public.track_ratings
    where track_id = (select id from ids where position = 1)), 'las notas de A siguen intactas');
select set_config('request.jwt.claim.sub', 'f2000000-0000-4000-8000-000000000001', true);
set local role authenticated;
delete from public.listening_sessions where id = 'a2000000-0000-4000-8000-00000000000a';
reset role;
select pg_temp.assert_true(not exists(select 1 from public.session_tracks
    where session_id = 'a2000000-0000-4000-8000-00000000000a'), 'borrar la sesión borra sus canciones');
select pg_temp.assert_true(not exists(select 1 from public.track_ratings
    where user_id = 'f2000000-0000-4000-8000-000000000001'), 'borrar la sesión borra sus notas');
delete from auth.users where id = 'f2000000-0000-4000-8000-000000000002';
select pg_temp.assert_true(not exists(select 1 from public.listening_sessions
    where id = 'b2000000-0000-4000-8000-00000000000b'), 'borrar la cuenta borra sus sesiones');

rollback;
select 'PASS: reviews, notas, permisos y borrados en cascada' as result;
