CREATE TABLE if not exists public.authuser (
	id bigserial NOT NULL,
	firstname varchar(100) NULL,
	lastname varchar(100) NULL,
	email varchar(100) NULL,
	username varchar(100) NULL,
	password_pw varchar(48) NULL,
	password_slt varchar(20) NULL,
	provider varchar(100) NULL,
	locale varchar(16) NULL,
	validated bool NULL,
	user_c int8 NULL,
	uniqueid varchar(32) NULL,
	createdat timestamp NULL,
	updatedat timestamp NULL,
	timezone varchar(32) NULL,
	superuser bool NULL,
	passwordshouldbechanged bool NULL,
	CONSTRAINT authuser_pk PRIMARY KEY (id)
);
CREATE INDEX authuser_uniqueid ON public.authuser USING btree (uniqueid);
CREATE INDEX authuser_user_c ON public.authuser USING btree (user_c);
CREATE UNIQUE INDEX authuser_username_provider ON public.authuser USING btree (username, provider);

insert into users (id, username, password)
INSERT INTO public.authuser (firstname,lastname,email,username,password_pw,password_slt,provider,locale,validated,user_c,uniqueid,createdat,updatedat,timezone,superuser,passwordshouldbechanged) VALUES
	 ('Aria','Milic','marko@tesobe.com','aria.milic','b;$2a$10$SGIAR0RtthMlgJK9DhElBekIvo5ulZ26GBZJQ','nXiDOLye3CtjzEke','http://127.0.0.1:8080','en_US',true,2,'LRE3RRDGPKMZALRDR0O0G350JTPTF0SK','2023-06-06 05:28:25.959','2023-06-06 05:28:25.967','UTC',false,NULL);