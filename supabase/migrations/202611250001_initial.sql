-- Run against a fresh Supabase project. Business writes use authenticated RPCs.
create extension if not exists postgis with schema extensions;
create extension if not exists btree_gist with schema extensions;
set search_path = public, extensions;
revoke create on schema public from public, anon, authenticated;
create table public.barbers (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id),
 name text not null, shop text not null, area text not null, bio text not null default '',
 location extensions.geography(Point,4326) not null,
 approved boolean not null default false, subscription_until timestamptz,
 initials text not null default 'B', color text not null default '#dbe6da',
 created_at timestamptz not null default now()
);
create index barbers_location_idx on public.barbers using gist(location);
create table public.services (
 id uuid primary key default gen_random_uuid(), barber_id uuid not null references public.barbers(id),
 name text not null check(name in ('Skin fade','Classic cut','Beard trim','Kids cut')),
 price numeric(10,2) not null check(price>=0), duration integer not null check(duration between 15 and 240),
 currency text not null default 'USD' check(currency='USD'), unique(barber_id,name)
);
create table public.working_hours (
 barber_id uuid references public.barbers(id), weekday integer check(weekday between 0 and 6),
 opens time not null, closes time not null, primary key(barber_id,weekday), check(opens<closes)
);
create table public.time_off (
 id uuid primary key default gen_random_uuid(), barber_id uuid not null references public.barbers(id),
 start timestamptz not null, finish timestamptz not null, check(finish>start)
);
create table public.bookings (
 id uuid primary key default gen_random_uuid(), "barberId" uuid not null references public.barbers(id),
 "userId" uuid not null references auth.users(id), "barberName" text not null, shop text not null,
 service text not null, start timestamptz not null, "end" timestamptz not null,
 price numeric(10,2) not null, currency text not null, status text not null default 'confirmed' check(status in ('confirmed','cancelled','completed')),
 created_at timestamptz not null default now(), check("end">start),
 exclude using gist ("barberId" with =, tstzrange(start,"end",'[)') with &&) where (status='confirmed')
);
create index bookings_customer_idx on public.bookings("userId",start);
alter table public.barbers enable row level security;
alter table public.services enable row level security;
alter table public.working_hours enable row level security;
alter table public.time_off enable row level security;
alter table public.bookings enable row level security;
-- Public discovery is through restricted RPC projections, not owner identifiers.
revoke all on public.barbers,public.services,public.working_hours,public.time_off,public.bookings from anon,authenticated;
grant select on public.bookings to authenticated;
create policy customer_reads_own_bookings on public.bookings for select to authenticated using("userId"=auth.uid());

create function public.search_barbers(p_lat double precision,p_lng double precision,p_radius double precision default 20,p_service text default null,p_max_price numeric default 100)
returns jsonb language sql stable security definer set search_path=public,extensions as $$
 select coalesce(jsonb_agg(item order by distance),'[]'::jsonb) from (
 select st_distance(b.location,st_setsrid(st_makepoint(p_lng,p_lat),4326)::geography)/1000 distance,
 jsonb_build_object('id',b.id,'name',b.name,'shop',b.shop,'area',b.area,'bio',b.bio,'initials',b.initials,'color',b.color,
 'lat',st_y(b.location::geometry),'lng',st_x(b.location::geometry),'rating',null,'reviews',0,
 'distance',st_distance(b.location,st_setsrid(st_makepoint(p_lng,p_lat),4326)::geography)/1000,
 'services',(select jsonb_agg(jsonb_build_object('name',s.name,'price',s.price,'duration',s.duration)) from services s where s.barber_id=b.id and (p_service is null or s.name=p_service) and s.price<=p_max_price)) item
 from barbers b where b.approved and b.subscription_until>now()
 and st_dwithin(b.location,st_setsrid(st_makepoint(p_lng,p_lat),4326)::geography,least(greatest(p_radius,0),100)*1000)
 and exists(select 1 from services s where s.barber_id=b.id and (p_service is null or s.name=p_service) and s.price<=p_max_price)
 order by distance limit 100) candidates;
$$;
create function public.available_slots(p_barber uuid,p_date date,p_service text)
returns jsonb language sql stable security definer set search_path=public,extensions as $$
 select coalesce(jsonb_agg(slot order by slot),'[]'::jsonb) from (
 select g slot from barbers b join services s on s.barber_id=b.id
 join working_hours h on h.barber_id=b.id and h.weekday=extract(dow from p_date)
 cross join lateral generate_series((p_date+h.opens) at time zone 'Africa/Harare', ((p_date+h.closes) at time zone 'Africa/Harare')-make_interval(mins=>s.duration),interval '30 minutes') g
 where b.id=p_barber and b.approved and b.subscription_until>now() and s.name=p_service and g>now()
 and p_date between (now() at time zone 'Africa/Harare')::date and (now() at time zone 'Africa/Harare')::date+60
 and not exists(select 1 from bookings a where a."barberId"=b.id and a.status='confirmed' and tstzrange(a.start,a."end",'[)') && tstzrange(g,g+make_interval(mins=>s.duration),'[)'))
 and not exists(select 1 from time_off t where t.barber_id=b.id and tstzrange(t.start,t.finish,'[)') && tstzrange(g,g+make_interval(mins=>s.duration),'[)'))
 ) slots;
$$;
create function public.create_booking(p_barber uuid,p_service text,p_start timestamptz)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare b barbers; s services; result bookings; valid boolean;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 -- Serialise availability evaluation and writes for one barber.
 select * into b from barbers where id=p_barber for update;
 select * into s from services where barber_id=p_barber and name=p_service;
 select exists(select 1 from jsonb_array_elements_text(available_slots(p_barber,(p_start at time zone 'Africa/Harare')::date,p_service)) slot where slot::timestamptz=p_start) into valid;
 if not valid then raise exception 'Appointment unavailable'; end if;
 insert into bookings("barberId","userId","barberName",shop,service,start,"end",price,currency)
 values(b.id,auth.uid(),b.name,b.shop,s.name,p_start,p_start+make_interval(mins=>s.duration),s.price,s.currency) returning * into result;
 return to_jsonb(result);
end;
$$;
create function public.cancel_booking(p_booking uuid) returns jsonb language plpgsql security definer set search_path=public as $$
declare result bookings;
begin
 update bookings set status='cancelled' where id=p_booking and "userId"=auth.uid() and status='confirmed' and start>now() returning * into result;
 if result.id is null then raise exception 'Booking cannot be cancelled'; end if;
 return to_jsonb(result);
end;
$$;
revoke all on function public.search_barbers(double precision,double precision,double precision,text,numeric),public.available_slots(uuid,date,text),public.create_booking(uuid,text,timestamptz),public.cancel_booking(uuid) from public;
grant execute on function public.search_barbers(double precision,double precision,double precision,text,numeric),public.available_slots(uuid,date,text) to anon,authenticated;
grant execute on function public.create_booking(uuid,text,timestamptz),public.cancel_booking(uuid) to authenticated;
