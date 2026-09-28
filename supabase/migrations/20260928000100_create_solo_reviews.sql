-- RF-008, RF-009, RF-010 (versión individual), RNF-001, RNF-003, RNF-004
-- Milestone 2: una persona registra un álbum, puntúa sus canciones y consulta su historial.
-- La media del álbum no se guarda: se calcula a partir de las notas de las canciones.
begin;

-- Una sesión de escucha es una ocasión: volver a escuchar el álbum crea otra.
create table public.listening_sessions (
    id uuid primary key default gen_random_uuid(),
    owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
    album_title text not null,
    artist_name text not null,
    created_at timestamptz not null default now(),

    constraint listening_sessions_album_title_format check (
        char_length(album_title) between 1 and 200
        and album_title = btrim(album_title)
        and album_title !~ '^[[:space:]]|[[:space:]]$'
        and album_title !~ '[[:cntrl:]]'
    ),
    constraint listening_sessions_artist_name_format check (
        char_length(artist_name) between 1 and 200
        and artist_name = btrim(artist_name)
        and artist_name !~ '^[[:space:]]|[[:space:]]$'
        and artist_name !~ '[[:cntrl:]]'
    )
);

create index listening_sessions_owner_created_idx
    on public.listening_sessions (owner_id, created_at desc);

create table public.session_tracks (
    id uuid primary key default gen_random_uuid(),
    session_id uuid not null references public.listening_sessions(id) on delete cascade,
    position smallint not null,
    title text not null,

    constraint session_tracks_position_key unique (session_id, position),
    constraint session_tracks_position_range check (position between 1 and 100),
    constraint session_tracks_title_format check (
        char_length(title) between 1 and 200
        and title = btrim(title)
        and title !~ '^[[:space:]]|[[:space:]]$'
        and title !~ '[[:cntrl:]]'
    )
);

-- Una nota por persona y canción. user_id ya prepara el milestone 3 (varios participantes).
create table public.track_ratings (
    track_id uuid not null references public.session_tracks(id) on delete cascade,
    user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
    -- numeric sin precisión fija: 8.25 se rechaza en lugar de redondearse en silencio.
    score numeric not null,
    comment text,

    primary key (track_id, user_id),
    constraint track_ratings_score_range check (
        score between 1 and 10 and score = round(score, 1)
    ),
    constraint track_ratings_comment_format check (
        comment is null or (char_length(comment) between 1 and 1000 and comment = btrim(comment))
    )
);

create index track_ratings_user_idx on public.track_ratings (user_id);

alter table public.listening_sessions enable row level security;
alter table public.session_tracks enable row level security;
alter table public.track_ratings enable row level security;

revoke all on table public.listening_sessions, public.session_tracks, public.track_ratings
    from public, anon, authenticated;

-- owner_id y user_id no se pueden elegir: los asigna auth.uid() por defecto.
-- Las canciones no se editan; borrar la sesión las borra en cascada.
grant select, delete on public.listening_sessions to authenticated;
grant insert (id, album_title, artist_name) on public.listening_sessions to authenticated;
grant select on public.session_tracks to authenticated;
grant insert (session_id, position, title) on public.session_tracks to authenticated;
grant select, delete on public.track_ratings to authenticated;
grant insert (track_id, score, comment) on public.track_ratings to authenticated;
grant update (score, comment) on public.track_ratings to authenticated;

create policy listening_sessions_select_own
    on public.listening_sessions for select to authenticated
    using ((select auth.uid()) = owner_id);

create policy listening_sessions_insert_own
    on public.listening_sessions for insert to authenticated
    with check ((select auth.uid()) = owner_id);

create policy listening_sessions_delete_own
    on public.listening_sessions for delete to authenticated
    using ((select auth.uid()) = owner_id);

create policy session_tracks_select_own
    on public.session_tracks for select to authenticated
    using (exists (
        select 1 from public.listening_sessions s
        where s.id = session_id and s.owner_id = (select auth.uid())
    ));

create policy session_tracks_insert_own
    on public.session_tracks for insert to authenticated
    with check (exists (
        select 1 from public.listening_sessions s
        where s.id = session_id and s.owner_id = (select auth.uid())
    ));

create policy track_ratings_select_own
    on public.track_ratings for select to authenticated
    using ((select auth.uid()) = user_id);

-- Solo se puntúan canciones de una sesión propia. En el milestone 3 esta
-- comprobación pasará a ser «participante de la sesión».
create policy track_ratings_insert_own
    on public.track_ratings for insert to authenticated
    with check (
        (select auth.uid()) = user_id
        and exists (
            select 1 from public.session_tracks t
            join public.listening_sessions s on s.id = t.session_id
            where t.id = track_id and s.owner_id = (select auth.uid())
        )
    );

create policy track_ratings_update_own
    on public.track_ratings for update to authenticated
    using ((select auth.uid()) = user_id)
    with check ((select auth.uid()) = user_id);

create policy track_ratings_delete_own
    on public.track_ratings for delete to authenticated
    using ((select auth.uid()) = user_id);

-- Crea la sesión y sus canciones en una sola transacción: nunca queda un álbum sin canciones.
-- La app genera p_id para que reintentar tras perder la respuesta no cree un duplicado.
-- security invoker: se ejecuta con los permisos y las políticas de quien la llama.
create function public.create_listening_session(
    p_id uuid,
    p_album_title text,
    p_artist_name text,
    p_track_titles text[]
) returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
begin
    if coalesce(cardinality(p_track_titles), 0) not between 1 and 100 then
        raise exception 'Un álbum necesita entre 1 y 100 canciones' using errcode = '22023';
    end if;

    insert into public.listening_sessions (id, album_title, artist_name)
    values (p_id, p_album_title, p_artist_name);

    insert into public.session_tracks (session_id, position, title)
    select p_id, t.position::smallint, t.title
    from unnest(p_track_titles) with ordinality as t(title, position);

    return p_id;
end;
$$;

-- Guarda o sustituye la nota propia de una canción. Repetir la llamada da el mismo resultado.
create function public.set_track_rating(
    p_track_id uuid,
    p_score numeric,
    p_comment text default null
) returns void
language sql
security invoker
set search_path = ''
as $$
    insert into public.track_ratings (track_id, score, comment)
    values (p_track_id, p_score, p_comment)
    on conflict (track_id, user_id) do update
    set score = excluded.score, comment = excluded.comment;
$$;

revoke all on function public.create_listening_session(uuid, text, text, text[])
    from public, anon, authenticated;
revoke all on function public.set_track_rating(uuid, numeric, text)
    from public, anon, authenticated;
grant execute on function public.create_listening_session(uuid, text, text, text[]) to authenticated;
grant execute on function public.set_track_rating(uuid, numeric, text) to authenticated;

commit;
