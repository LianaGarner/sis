-- Run once in Supabase: SQL Editor > New query > paste > Run
create table profiles(id uuid primary key references auth.users on delete cascade, role text not null default 'student' check(role in('admin','teacher','student')), full_name text not null, student_code text unique, email text, grade_level int not null default 10);
-- Private details: visible only to the student herself and admin (never teachers)
create table student_private(id uuid primary key references profiles on delete cascade, father_name text, whatsapp text, notes text);
create table courses(id uuid primary key default gen_random_uuid(), name text not null, subject text not null, credits numeric not null default 1);
create table classes(id uuid primary key default gen_random_uuid(), course_id uuid not null references courses, teacher_id uuid references profiles on delete set null, school_year text not null, term text not null check(term in('Fall','Spring')), pass_pct numeric not null default 60);
create table enrollments(id uuid primary key default gen_random_uuid(), class_id uuid not null references classes on delete cascade, student_id uuid not null references profiles on delete cascade, final_override text check(final_override in('Pass','Fail')), unique(class_id,student_id));
create table assignments(id uuid primary key default gen_random_uuid(), class_id uuid not null references classes on delete cascade, title text not null, points_possible numeric not null);
create table scores(assignment_id uuid references assignments on delete cascade, student_id uuid references profiles on delete cascade, points numeric not null, primary key(assignment_id,student_id));
create table requirements(subject text primary key, credits_required numeric not null);

create function is_admin() returns boolean language sql stable security definer set search_path=public as $$select exists(select 1 from profiles where id=auth.uid() and role='admin')$$;
create function can_teach(cid uuid) returns boolean language sql stable security definer set search_path=public as $$select is_admin() or exists(select 1 from classes where id=cid and teacher_id=auth.uid())$$;
create function in_class(cid uuid) returns boolean language sql stable security definer set search_path=public as $$select exists(select 1 from enrollments where class_id=cid and student_id=auth.uid())$$;
create function teaches_student(sid uuid) returns boolean language sql stable security definer set search_path=public as $$select exists(select 1 from enrollments e join classes c on c.id=e.class_id where e.student_id=sid and c.teacher_id=auth.uid())$$;

alter table profiles enable row level security; alter table courses enable row level security; alter table classes enable row level security; alter table enrollments enable row level security; alter table assignments enable row level security; alter table scores enable row level security; alter table requirements enable row level security;

create policy p_sel on profiles for select using(id=auth.uid() or is_admin() or teaches_student(id));
create policy p_adm on profiles for all using(is_admin()) with check(is_admin());
create policy co_sel on courses for select using(auth.uid() is not null);
create policy co_adm on courses for all using(is_admin()) with check(is_admin());
create policy rq_sel on requirements for select using(auth.uid() is not null);
create policy rq_adm on requirements for all using(is_admin()) with check(is_admin());
create policy cl_sel on classes for select using(can_teach(id) or in_class(id));
create policy cl_adm on classes for all using(is_admin()) with check(is_admin());
create policy en_sel on enrollments for select using(student_id=auth.uid() or can_teach(class_id));
create policy en_upd on enrollments for update using(can_teach(class_id)) with check(can_teach(class_id));
create policy en_adm on enrollments for all using(is_admin()) with check(is_admin());
revoke update on enrollments from authenticated; grant update(final_override) on enrollments to authenticated;
create policy as_sel on assignments for select using(can_teach(class_id) or in_class(class_id));
create policy as_w on assignments for all using(can_teach(class_id)) with check(can_teach(class_id));
create policy sc_sel on scores for select using(student_id=auth.uid() or can_teach((select class_id from assignments where id=assignment_id)));
create policy sc_w on scores for all using(can_teach((select class_id from assignments where id=assignment_id))) with check(can_teach((select class_id from assignments where id=assignment_id)));

-- Auto student ID (e.g. 260001 = year + number); can be edited by admin afterwards
create sequence student_seq start 1;
create function set_student_code() returns trigger language plpgsql as $$begin if new.role='student' and coalesce(new.student_code,'')='' then new.student_code:=to_char(now(),'YY')||lpad(nextval('student_seq')::text,4,'0'); end if; return new; end$$;
create trigger t_code before insert on profiles for each row execute function set_student_code();
create function make_private() returns trigger language plpgsql security definer set search_path=public as $$begin if new.role='student' then insert into student_private(id) values(new.id) on conflict do nothing; end if; return new; end$$;
create trigger t_priv after insert on profiles for each row execute function make_private();
alter table student_private enable row level security;
create policy sp_sel on student_private for select using(id=auth.uid() or is_admin());
create policy sp_adm on student_private for all using(is_admin()) with check(is_admin());

-- Results per enrollment: auto Pass/Fail from points (only scored assignments count), teacher override wins
create view enrollment_results with(security_invoker=true) as
select *, coalesce(final_override, auto_result) as result from (
 select e.id enrollment_id, e.student_id, e.class_id, e.final_override, c.school_year, c.term, co.name course, co.subject, co.credits, s.earned, s.possible,
  case when s.possible>0 then case when s.earned/s.possible*100>=c.pass_pct then 'Pass' else 'Fail' end end auto_result
 from enrollments e join classes c on c.id=e.class_id join courses co on co.id=c.course_id
 left join lateral (select sum(sc.points) earned, sum(a.points_possible) possible from assignments a join scores sc on sc.assignment_id=a.id and sc.student_id=e.student_id where a.class_id=e.class_id) s on true) x;

-- After creating YOUR login under Authentication > Users, make yourself admin (change the email):
-- insert into profiles(id,role,full_name) select id,'admin','Your Name' from auth.users where email='you@example.com';
