-- Data Definition Log 

-- This thing aspires to provide a unified standard for different
-- migration tools. It is used only to keep track of data definition
-- changes in the scope of its own DB.
create schema if not exists ddlog;

create table if not exists ddlog.ddlog (
       applied_at timestamptz default now() unique,
       new_state text,
       sql text not null,
       context json,
       output text,
       success bool
);

-- The basic idea is to save in the target DB every data definition
-- script that was executed, together with a timestamp. We save the
-- script in the "sql" field and the timestamp in the "applied_at" field.

-- Optionally, the migration tool will also save the script
-- "output". It is highly recommended to also log failed
-- migrations. For that purpose, there is the "success" field that
-- defaults to True.

-- The script saved in "sql" is not always reproducible. It may depend
-- on environment variables or user input for example. It is ok, this
-- is a feature not a bug. The migration tool can use the field
-- "context" to provide additional details that are not explicit in
-- the "sql" script.

-- Although optional, the field "new_state" plays a key role. If after
-- running a migration script the schema is in a different state (this
-- is the usual case), a value should be provided to "new_state". The
-- meaning of a NULL "new_state" is that the state was not changed
-- when applying this script.

-- Then, we can compute the current state with the following function.
create or replace function ddlog.current_state() returns text
language sql stable
begin atomic;
      select new_state
      from ddlog.ddlog
      where new_state is not null
      order by applied_at desc
      limit 1;
end;

-- Finally, we want to ensure that the migrations log is not
-- altered. It should behave as an immutable table. With the following
-- policies, we disallow update or delete when the "success" field is
-- not null. So, marking this field means that the script finished
-- execution.

alter table ddlog.ddlog enable row level security;
-- enable for table owner as well
alter table ddlog.ddlog force row level security; 

create policy allow_all on ddlog.ddlog for all using (true);

create policy do_not_delete_marked on ddlog.ddlog
       as restrictive for delete
       using (success is  null);

create policy do_not_update_marked on ddlog.ddlog
       as restrictive for update
       using (success is  null);

-- WARNING: from the docs, "Superusers and roles with the BYPASSRLS
-- attribute always bypass the row security system when accessing a
-- table"
