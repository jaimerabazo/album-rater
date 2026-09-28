-- Permisos y restricciones de las reviews (RF-008, RF-009, RF-010, RNF-001, RNF-003, RNF-004).
-- Ejecutar con `supabase test db`. Todo ocurre en una transacción que se revierte.
begin;
create extension if not exists pgtap with schema extensions;
select plan(58);

select ok((select bool_and(relrowsecurity) from pg_class
    where oid in ('public.listening_sessions'::regclass, 'public.session_tracks'::regclass, 'public.track_ratings'::regclass)),
    'RLS activado en las tres tablas');
select hasnt_column('public', 'listening_sessions', 'average_score', 'la media no se guarda: se calcula');

insert into auth.users (id) values
('f2000000-0000-4000-8000-000000000001'),
('f2000000-0000-4000-8000-000000000002');

-- A crea un álbum con tres canciones.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'f2000000-0000-4000-8000-000000000001', true);
select is(public.create_listening_session('a2000000-0000-4000-8000-00000000000a', 'Álbum A', 'Artista',
    array['Uno', 'Dos', 'Tres']), 'a2000000-0000-4000-8000-00000000000a'::uuid, 'crear sesión devuelve su id');
select is((select owner_id from public.listening_sessions), 'f2000000-0000-4000-8000-000000000001'::uuid,
    'owner_id lo asigna el servidor');
select is((select array_agg(title order by position) from public.session_tracks), array['Uno', 'Dos', 'Tres'],
    'canciones en orden');

-- Reintento con el mismo id: no crea un duplicado.
select throws_ok($$select public.create_listening_session('a2000000-0000-4000-8000-00000000000a', 'Álbum A',
    'Artista', array['Uno'])$$, '23505', null, 'reintentar con el mismo id falla');
select is((select count(*) from public.session_tracks), 3::bigint, 'el reintento no añade canciones');

-- Validación
select throws_ok($$select public.create_listening_session(gen_random_uuid(), 'X', 'Y', array[]::text[])$$,
    '22023', null, 'sin canciones');
select throws_ok($$select public.create_listening_session(gen_random_uuid(), 'X', 'Y', null)$$,
    '22023', null, 'lista de canciones nula');
select throws_ok($$select public.create_listening_session(gen_random_uuid(), 'X', 'Y', array_fill('a'::text, array[101]))$$,
    '22023', null, 'más de 100 canciones');
select lives_ok($$select public.create_listening_session('a2000000-0000-4000-8000-0000000000cc', 'X', 'Y',
    array_fill(repeat('t', 200), array[100]))$$, '100 canciones de 200 caracteres');
select throws_ok($$select public.create_listening_session(gen_random_uuid(), ' ', 'Y', array['a'])$$,
    '23514', null, 'título vacío');
select throws_ok($$select public.create_listening_session(gen_random_uuid(), repeat('a', 201), 'Y', array['a'])$$,
    '23514', null, 'título de más de 200 caracteres');
select throws_ok($$select public.create_listening_session(gen_random_uuid(), E'X\nZ', 'Y', array['a'])$$,
    '23514', null, 'título con salto de línea');
select throws_ok($$select public.create_listening_session(gen_random_uuid(), 'X', '', array['a'])$$,
    '23514', null, 'artista vacío');
select throws_ok($$select public.create_listening_session(gen_random_uuid(), 'X', 'Y', array['a', ''])$$,
    '23514', null, 'canción sin título');
select throws_ok($$select public.create_listening_session(gen_random_uuid(), 'X', 'Y', array['a', E'b\tc'])$$,
    '23514', null, 'canción con tabulador');
select throws_ok($$select public.create_listening_session(gen_random_uuid(), 'X', 'Y', array['a', null])$$,
    '23502', null, 'canción nula');
select is((select count(*) from public.listening_sessions), 2::bigint, 'los fallos no dejan sesiones a medias');
delete from public.listening_sessions where id = 'a2000000-0000-4000-8000-0000000000cc';

-- No se puede elegir el propietario ni editar canciones o títulos.
select throws_ok($$insert into public.listening_sessions (album_title, artist_name, owner_id)
    values ('X', 'Y', 'f2000000-0000-4000-8000-000000000002')$$, '42501', null, 'owner_id no se elige');
select throws_ok($$update public.session_tracks set title = 'Otro'$$, '42501', null, 'las canciones no se editan');
select throws_ok($$update public.listening_sessions set album_title = 'Otro'$$, '42501', null, 'el álbum no se edita');
select throws_ok($$delete from public.session_tracks$$, '42501', null, 'las canciones no se borran sueltas');

-- Notas: de 1 a 10 con un decimal como máximo.
create temp table ids as select position, id from public.session_tracks order by position;
grant select on ids to authenticated, anon;
select lives_ok($$select public.set_track_rating((select id from ids where position = 1), 9)$$, 'nota sin comentario');
select lives_ok($$select public.set_track_rating((select id from ids where position = 2), 8, 'Muy buena')$$, 'nota con comentario');
select is((select avg(score) from public.track_ratings), 8.5, 'la media de 9 y 8 es 8,5');
select lives_ok($$select public.set_track_rating((select id from ids where position = 2), 7.5, null)$$, 'volver a puntuar');
select is((select score from public.track_ratings where track_id = (select id from ids where position = 2)), 7.5,
    'la nota se sustituye');
select is((select comment from public.track_ratings where track_id = (select id from ids where position = 2)), null,
    'el comentario se sustituye');
select is((select count(*) from public.track_ratings), 2::bigint, 'una nota por persona y canción');
select lives_ok($$select public.set_track_rating((select id from ids where position = 3), 1)$$, 'nota mínima 1');
select lives_ok($$select public.set_track_rating((select id from ids where position = 3), 10)$$, 'nota máxima 10');
select throws_ok($$select public.set_track_rating((select id from ids where position = 3), 0.9)$$, '23514', null, 'menos de 1');
select throws_ok($$select public.set_track_rating((select id from ids where position = 3), 10.1)$$, '23514', null, 'más de 10');
select throws_ok($$select public.set_track_rating((select id from ids where position = 3), 8.25)$$, '23514', null,
    'dos decimales se rechazan, no se redondean');
select throws_ok($$select public.set_track_rating((select id from ids where position = 3), null)$$, '23502', null, 'nota obligatoria');
select throws_ok($$select public.set_track_rating((select id from ids where position = 3), 8, repeat('a', 1001))$$,
    '23514', null, 'comentario de más de 1000 caracteres');
select throws_ok($$select public.set_track_rating((select id from ids where position = 3), 8, ' ')$$,
    '23514', null, 'comentario en blanco');
select throws_ok($$update public.track_ratings set user_id = 'f2000000-0000-4000-8000-000000000002'$$,
    '42501', null, 'user_id no se cambia');
select throws_ok($$update public.track_ratings set track_id = (select id from ids where position = 1)$$,
    '42501', null, 'una nota no cambia de canción');
select lives_ok($$delete from public.track_ratings where track_id = (select id from ids where position = 3)$$, 'quitar la nota propia');
select is((select count(*) from public.track_ratings), 2::bigint, 'la nota se quita');

-- B no ve ni modifica nada de A.
select set_config('request.jwt.claim.sub', 'f2000000-0000-4000-8000-000000000002', true);
select is((select count(*) from public.listening_sessions), 0::bigint, 'B no ve sesiones de A');
select is((select count(*) from public.session_tracks), 0::bigint, 'B no ve canciones de A');
select is((select count(*) from public.track_ratings), 0::bigint, 'B no ve notas de A');
select throws_ok($$insert into public.session_tracks (session_id, position, title)
    values ('a2000000-0000-4000-8000-00000000000a', 4, 'Intrusa')$$, '42501', null, 'B no añade canciones a A');
select throws_ok($$select public.set_track_rating((select id from ids where position = 3), 5)$$,
    '42501', null, 'B no puntúa canciones de A');
with removed as (
    delete from public.listening_sessions where id = 'a2000000-0000-4000-8000-00000000000a' returning id
) select is(count(*), 0::bigint, 'B no borra la sesión de A') from removed;
with removed as (
    delete from public.track_ratings returning track_id
) select is(count(*), 0::bigint, 'B no borra notas de A') from removed;
select lives_ok($$select public.create_listening_session('b2000000-0000-4000-8000-00000000000b', 'Álbum B',
    'Artista', array['Uno'])$$, 'B crea su álbum');
select is((select count(*) from public.listening_sessions), 1::bigint, 'B solo ve su sesión');

-- Sin sesión no hay acceso.
set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select throws_ok('select * from public.listening_sessions', '42501', null, 'sin sesión no se leen sesiones');
select throws_ok('select * from public.track_ratings', '42501', null, 'sin sesión no se leen notas');
select throws_ok($$select public.create_listening_session(gen_random_uuid(), 'X', 'Y', array['a'])$$,
    '42501', null, 'sin sesión no se crean álbumes');
select throws_ok($$select public.set_track_rating((select id from ids where position = 1), 5)$$,
    '42501', null, 'sin sesión no se puntúa');

-- Borrados en cascada.
reset role;
select is((select score from public.track_ratings where track_id = (select id from ids where position = 1)), 9::numeric,
    'las notas de A siguen intactas');
select set_config('request.jwt.claim.sub', 'f2000000-0000-4000-8000-000000000001', true);
set local role authenticated;
delete from public.listening_sessions where id = 'a2000000-0000-4000-8000-00000000000a';
reset role;
select ok(not exists(select 1 from public.session_tracks where session_id = 'a2000000-0000-4000-8000-00000000000a')
    and not exists(select 1 from public.track_ratings where user_id = 'f2000000-0000-4000-8000-000000000001'),
    'borrar la sesión borra sus canciones y notas');
delete from auth.users where id = 'f2000000-0000-4000-8000-000000000002';
select ok(not exists(select 1 from public.listening_sessions where id = 'b2000000-0000-4000-8000-00000000000b'),
    'borrar la cuenta borra sus sesiones');

select * from finish();
rollback;
