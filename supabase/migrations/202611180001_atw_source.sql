-- Run in the intended ATW Source project, using Supabase SQL Editor or db push.
begin;
create table if not exists public.atw_members (
 email text primary key check(email=lower(email)), name text not null,
 role text not null check(role in ('Administrator','Procurement Officer','Senior Procurement Officer','Procurement Supervisor','Procurement Expeditor','Procurement Senior Manager','Procurement Distribution','Engineering','Project','Warehouse','Finance','Management','Staff','Vendor')),
 division text, vendor_id text, entities text[] not null default '{}', active boolean not null default true,
 check(role <> 'Vendor' or vendor_id is not null),
 check(role <> 'Administrator' or email='noor.sari@atwsolar.com')
);
insert into public.atw_members(email,name,role,division) values('noor.sari@atwsolar.com','Noor Sari','Administrator','PRC') on conflict(email) do nothing;
create table if not exists public.atw_records (
 domain text not null, reference text not null, entity text not null,
 vendor_id text, requester_email text, division text, payload jsonb not null default '{}',
 version bigint not null default 1, created_by text not null, source text not null default 'atwsource',
 updated_at timestamptz not null default now(), primary key(domain,reference,entity)
);
create index if not exists atw_records_vendor on public.atw_records(vendor_id,domain);
create table if not exists public.atw_record_access (
 domain text not null, reference text not null, entity text not null, vendor_id text not null,
 primary key(domain,reference,entity,vendor_id), foreign key(domain,reference,entity) references public.atw_records on delete cascade
);
create table if not exists public.atw_user_state (
 email text not null, key text not null, value text, version bigint not null default 1, updated_at timestamptz not null default now(), primary key(email,key)
);
create table if not exists public.atw_documents (
 id uuid primary key default gen_random_uuid(),domain text not null, reference text not null, entity text not null,
 name text not null,size bigint not null check(size>0 and size<=12582912),mime text not null,
 storage_path text unique not null, uploaded_by text not null,status text not null default 'Pending upload' check(status in ('Pending upload','Available','Cancelled')),
 created_at timestamptz not null default now(), foreign key(domain,reference,entity) references public.atw_records
);
create table if not exists public.atw_audit (
 id bigint generated always as identity primary key, actor text not null, action text not null,
 reference text, detail jsonb not null default '{}',created_at timestamptz not null default now()
);
create table if not exists public.atw_settings(key text primary key,value jsonb not null,version bigint not null default 1);
create table if not exists public.atw_rate_limits(key text not null,window_start bigint not null,count integer not null,primary key(key,window_start));

create or replace function public.atw_actor() returns public.atw_members language sql stable security definer set search_path='' as $$
 select m from public.atw_members m where m.email=lower(auth.jwt()->>'email') and m.active and auth.uid() is not null
$$;
create or replace function public.atw_can_read(p_domain text,p_reference text,p_entity text) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.atw_records r cross join lateral public.atw_actor() a
 where r.domain=p_domain and r.reference=p_reference and r.entity=p_entity and a.email is not null
 and (cardinality(a.entities)=0 or r.entity=any(a.entities)) and
 (a.role in ('Administrator','Procurement Officer','Senior Procurement Officer','Procurement Supervisor','Procurement Expeditor','Procurement Senior Manager','Finance','Management')
 or (a.role='Vendor' and (r.vendor_id=a.vendor_id or exists(select 1 from public.atw_record_access x where (x.domain,x.reference,x.entity)=(r.domain,r.reference,r.entity) and x.vendor_id=a.vendor_id)))
 or (a.role<>'Vendor' and (r.requester_email=a.email or (a.division is not null and r.division=a.division) or r.domain in ('item','price')))))
$$;
alter table public.atw_members enable row level security;
alter table public.atw_records enable row level security;
alter table public.atw_record_access enable row level security;
alter table public.atw_user_state enable row level security;
alter table public.atw_documents enable row level security;
alter table public.atw_audit enable row level security;
alter table public.atw_settings enable row level security;
alter table public.atw_rate_limits enable row level security;
drop policy if exists member_self on public.atw_members;
create policy member_self on public.atw_members for select to authenticated using(email=lower(auth.jwt()->>'email') and active);
drop policy if exists record_scoped on public.atw_records;
create policy record_scoped on public.atw_records for select to authenticated using(public.atw_can_read(domain,reference,entity));
drop policy if exists state_self on public.atw_user_state;
create policy state_self on public.atw_user_state for select to authenticated using(email=(public.atw_actor()).email);
drop policy if exists documents_scoped on public.atw_documents;
create policy documents_scoped on public.atw_documents for select to authenticated using(public.atw_can_read(domain,reference,entity) and (status='Available' or uploaded_by=(public.atw_actor()).email));
drop policy if exists audit_admin on public.atw_audit;
create policy audit_admin on public.atw_audit for select to authenticated using((public.atw_actor()).role='Administrator');
drop policy if exists settings_admin on public.atw_settings;
create policy settings_admin on public.atw_settings for select to authenticated using((public.atw_actor()).role='Administrator');
revoke all on public.atw_members,public.atw_records,public.atw_record_access,public.atw_user_state,public.atw_documents,public.atw_audit,public.atw_settings,public.atw_rate_limits from anon,authenticated;
grant select on public.atw_members,public.atw_records,public.atw_user_state,public.atw_documents,public.atw_audit,public.atw_settings to authenticated;

create or replace function public.atw_save_state(p_entries jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare a public.atw_members; entry jsonb; current_version bigint; result jsonb:='[]'; new_version bigint;
begin
 a:=public.atw_actor();if a.email is null then raise exception 'Registered account required' using errcode='42501';end if;
 if jsonb_typeof(p_entries)<>'array' or jsonb_array_length(p_entries)>100 then raise exception 'Invalid state batch';end if;
 for entry in select value from jsonb_array_elements(p_entries) order by value->>'key' loop
  if length(entry->>'key')>200 or entry->>'key' !~ '^ATW[A-Z0-9_:-]*' or length(coalesce(entry->>'value',''))>2000000 or entry->>'key' ~* '(token|password|secret|session)' then raise exception 'Unsupported workspace key';end if;
  perform pg_advisory_xact_lock(hashtextextended(a.email||'|'||(entry->>'key'),0));
  select version into current_version from public.atw_user_state where email=a.email and key=entry->>'key' for update;
  if coalesce(current_version,0)<>coalesce((entry->>'version')::bigint,0) then raise exception 'Workspace changed on another device' using errcode='40001';end if;
  new_version:=coalesce(current_version,0)+1;
  insert into public.atw_user_state(email,key,value,version) values(a.email,entry->>'key',entry->>'value',new_version)
  on conflict(email,key) do update set value=excluded.value,version=excluded.version,updated_at=now();
  result:=result||jsonb_build_array(jsonb_build_object('key',entry->>'key','version',new_version));
 end loop;
 insert into public.atw_audit(actor,action,detail) values(a.email,'workspace saved',jsonb_build_object('keys',jsonb_array_length(p_entries)));
 return result;
end $$;

create or replace function public.atw_save_draft(p_domain text,p_reference text,p_entity text,p_payload jsonb,p_version bigint default 0) returns public.atw_records language plpgsql security definer set search_path='' as $$
declare a public.atw_members; old public.atw_records; result public.atw_records; allowed boolean:=false;
begin
 a:=public.atw_actor();if a.email is null then raise exception 'Registered account required' using errcode='42501';end if;
 if p_entity not in ('ATWS','ATWH','ATWR') or (cardinality(a.entities)>0 and not p_entity=any(a.entities)) then raise exception 'Entity denied' using errcode='42501';end if;
 if length(p_reference)<3 or length(p_reference)>120 or jsonb_typeof(p_payload)<>'object' or pg_column_size(p_payload)>262144 then raise exception 'Invalid record';end if;
 if p_payload ?| array['approval','approved','approvedBy','approvedAt','approvalSteps','approvals','signature','verifiedBy','paidAt','issuedAt','releasedAt','stage','st','doc'] then raise exception 'Use the authorized approval workflow' using errcode='42501';end if;
 if a.role in ('Administrator','Procurement Officer','Senior Procurement Officer','Procurement Supervisor','Procurement Senior Manager') and p_domain in ('rfq','cqs','po','loa','spk','costing','priceRequest') then allowed:=true;end if;
 if a.role<>'Vendor' and (a.division is distinct from 'PRC' or a.role='Procurement Distribution' or a.email='procurement@atwsolar.com') and p_domain in ('ticket','manpower','itemRequest','priceRequest','costing') then allowed:=true;end if;
 if a.role='Vendor' and p_domain='quotation' and public.atw_can_read('rfq',p_payload->>'rfq',p_entity) then allowed:=true;end if;
 if not allowed then raise exception 'Draft action is not available for this role' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_domain||'|'||p_reference||'|'||p_entity,0));
 select * into old from public.atw_records where (domain,reference,entity)=(p_domain,p_reference,p_entity) for update;
 if coalesce(old.version,0)<>p_version then raise exception 'Record changed; reload' using errcode='40001';end if;
 if old.reference is not null and (old.created_by<>a.email or coalesce(old.payload->>'status','')<>'Draft') then raise exception 'Only your own draft can be edited' using errcode='42501';end if;
 insert into public.atw_records(domain,reference,entity,vendor_id,requester_email,division,payload,created_by)
 values(p_domain,p_reference,p_entity,case when a.role='Vendor' then a.vendor_id else null end,a.email,a.division,p_payload||jsonb_build_object('ref',p_reference,'entity',p_entity,'status','Draft','createdByEmail',a.email),a.email)
 on conflict(domain,reference,entity) do update set payload=excluded.payload,version=public.atw_records.version+1,updated_at=now() returning * into result;
 insert into public.atw_audit(actor,action,reference,detail) values(a.email,'draft saved',p_reference,jsonb_build_object('domain',p_domain,'version',result.version));
 return result;
end $$;

create or replace function public.atw_register_document(p_domain text,p_reference text,p_entity text,p_name text,p_size bigint,p_mime text) returns public.atw_documents language plpgsql security definer set search_path='' as $$
declare a public.atw_members; id uuid:=gen_random_uuid(); result public.atw_documents;
begin
 a:=public.atw_actor();if not public.atw_can_read(p_domain,p_reference,p_entity) then raise exception 'Record access denied' using errcode='42501';end if;
 if a.role='Vendor' and p_domain not in ('quotation','invoice','delivery','registration','vendorDocument') then raise exception 'Vendor attachment type denied' using errcode='42501';end if;
 if p_size<=0 or p_size>12582912 or length(p_name)>200 or p_name ~ '[/\\]' or p_mime not in ('application/pdf','image/png','image/jpeg','text/plain','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet') then raise exception 'Unsupported file';end if;
 insert into public.atw_documents(id,domain,reference,entity,name,size,mime,storage_path,uploaded_by) values(id,p_domain,p_reference,p_entity,p_name,p_size,p_mime,id::text||'/'||p_name,a.email) returning * into result;return result;
end $$;
create or replace function public.atw_complete_document(p_id uuid) returns public.atw_documents language plpgsql security definer set search_path='' as $$
declare a public.atw_members; d public.atw_documents;
begin
 a:=public.atw_actor();select * into d from public.atw_documents where id=p_id for update;
 if d.uploaded_by<>a.email or not public.atw_can_read(d.domain,d.reference,d.entity) then raise exception 'Document denied' using errcode='42501';end if;
 if not exists(select 1 from storage.objects o where o.bucket_id='atw-documents' and o.name=d.storage_path and (o.metadata->>'size')::bigint=d.size) then raise exception 'Upload is not complete';end if;
 update public.atw_documents set status='Available' where id=p_id returning * into d;
 insert into public.atw_audit(actor,action,reference) values(a.email,'document uploaded',d.reference);return d;
end $$;

create or replace function public.atw_rate_limit(p_key text,p_limit integer,p_seconds integer) returns boolean language plpgsql security definer set search_path='' as $$
declare n integer; w bigint:=floor(extract(epoch from now())/p_seconds);
begin
 insert into public.atw_rate_limits(key,window_start,count) values(p_key,w,1) on conflict(key,window_start) do update set count=public.atw_rate_limits.count+1 returning count into n;
 delete from public.atw_rate_limits where window_start<w-2 and key=p_key;return n<=p_limit;
end $$;
revoke all on function public.atw_rate_limit(text,integer,integer) from public,anon,authenticated;
grant execute on function public.atw_rate_limit(text,integer,integer) to service_role;
revoke all on function public.atw_save_state(jsonb),public.atw_save_draft(text,text,text,jsonb,bigint),public.atw_register_document(text,text,text,text,bigint,text),public.atw_complete_document(uuid),public.atw_actor(),public.atw_can_read(text,text,text) from public,anon;
grant execute on function public.atw_save_state(jsonb),public.atw_save_draft(text,text,text,jsonb,bigint),public.atw_register_document(text,text,text,text,bigint,text),public.atw_complete_document(uuid),public.atw_actor(),public.atw_can_read(text,text,text) to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('atw-documents','atw-documents',false,12582912,array['application/pdf','image/png','image/jpeg','text/plain','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet']) on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
drop policy if exists atw_private_read on storage.objects;
create policy atw_private_read on storage.objects for select to authenticated using(bucket_id='atw-documents' and exists(select 1 from public.atw_documents d where d.storage_path=storage.objects.name and d.status='Available' and public.atw_can_read(d.domain,d.reference,d.entity)));
drop policy if exists atw_private_upload on storage.objects;
create policy atw_private_upload on storage.objects for insert to authenticated with check(bucket_id='atw-documents' and exists(select 1 from public.atw_documents d where d.storage_path=storage.objects.name and d.uploaded_by=(public.atw_actor()).email and d.status='Pending upload' and public.atw_can_read(d.domain,d.reference,d.entity)));
commit;
