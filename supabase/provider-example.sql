-- Replace this UUID with a real Supabase Auth provider user before execution.
-- Run only as a project administrator. No client permissions are granted here.
do $$
declare owner_uuid uuid := '00000000-0000-0000-0000-000000000000'; barber_uuid uuid;
begin
 if not exists(select 1 from auth.users where id=owner_uuid) then raise exception 'Replace owner_uuid with an existing Auth user'; end if;
 insert into public.barbers(owner_id,name,shop,area,bio,location,approved,subscription_until,initials)
 values(owner_uuid,'Your barber name','Your shop','Avondale','Describe your barbering services',extensions.st_setsrid(extensions.st_makepoint(31.033,-17.790),4326)::extensions.geography,true,now()+interval '30 days','YN') returning id into barber_uuid;
 insert into public.services(barber_id,name,price,duration) values(barber_uuid,'Skin fade',8,45),(barber_uuid,'Classic cut',6,30);
 insert into public.working_hours(barber_id,weekday,opens,closes) select barber_uuid,n,'09:00'::time,'17:00'::time from generate_series(1,6) n;
end $$;
