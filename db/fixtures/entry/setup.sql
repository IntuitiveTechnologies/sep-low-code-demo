CREATE DATABASE app;
CREATE DATABASE motoradmin;
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

\connect motoradmin;

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

\connect app

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE OR REPLACE FUNCTION public.clean_keys()
                           RETURNS trigger AS
$BODY$
BEGIN
  NEW.title = REGEXP_REPLACE(NEW.title, '[/]+', '_', 'gi'); 
  NEW.title = REGEXP_REPLACE(NEW.title, '[^a-zA-Z0-9_\-]+', '', 'gi');
  RETURN NEW;
END;
$BODY$
LANGUAGE plpgsql;

CREATE OR REPLACE
FUNCTION public.set_current_timestamp_updated_at()
RETURNS trigger
LANGUAGE plpgsql AS 
$$ 
  DECLARE _new record;
  BEGIN _new := NEW;
  _new."updated_at" = NOW();
  RETURN _new;
  END;
$$;

---
--- DATABASE DUMP FROM 13-04-2022
---

CREATE TABLE public.agency_role_enum(
    value text NOT NULL,
    comment text,
    PRIMARY KEY (value),
    UNIQUE (value)
);

INSERT INTO agency_role_enum (value, comment) VALUES 
    ('agency_admin', NULL),
    ('cardholder', NULL)
ON CONFLICT DO NOTHING;

CREATE TABLE public.book (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    title character varying(100) NOT NULL,
    author character varying,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT book_pkey PRIMARY KEY (id),
    UNIQUE(title),
    CONSTRAINT only_chars_and_numbers_in_book_title CHECK(title ~ '^[a-zA-Z0-9:\- ]{2,}$'),
    CONSTRAINT only_chars_in_book_author CHECK(author ~ '^[a-zA-Zříš,.\- ]{2,}$')
);

CREATE TABLE public.agency (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL UNIQUE,
    comment text,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE public.library (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    name character varying(100) NOT NULL,
    address character varying,
    agency_id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT library_pkey PRIMARY KEY (id),
    CONSTRAINT agency_pkey FOREIGN KEY (agency_id) REFERENCES public.agency(id),
    UNIQUE(name),
    CONSTRAINT only_chars_and_numbers_in_library_name CHECK(name ~ '^[a-zA-Z0-9\-\/ ]{2,}$'),
    CONSTRAINT only_chars_and_numbers_in_library_address CHECK(address ~ '^[a-zA-Z0-9\- ]{2,}$')
);

CREATE TABLE public.user (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    name character varying(100) NOT NULL,
    address text,
    email text NOT NULL,
    otp_secret text,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT user_pkey PRIMARY KEY (id),
    UNIQUE(email),
    CONSTRAINT only_chars_in_user_name CHECK(name ~ '^[a-zA-Z _\-]{2,}$'),
    CONSTRAINT only_chars_and_numbers_in_user_address CHECK(address ~ '^[a-zA-Z0-9\- ]{2,}$')
);

CREATE TABLE agency_user (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    agency_id uuid NOT NULL,
    agency_role text NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user(id),
    CONSTRAINT agency_role_fkey FOREIGN KEY (agency_role) REFERENCES public.agency_role_enum(value),
    CONSTRAINT agency_id_fkey FOREIGN KEY (agency_id) REFERENCES public.agency(id),
    UNIQUE(user_id, agency_id, agency_role)
);

CREATE TABLE public.library_book (
    library_id uuid NOT NULL,
    book_id uuid NOT NULL,
    CONSTRAINT library_book_pkey PRIMARY KEY (library_id, book_id),
    CONSTRAINT library_id_fkey FOREIGN KEY (library_id) REFERENCES public.library(id),
    CONSTRAINT book_id_fkey FOREIGN KEY (book_id) REFERENCES public.book(id)
);

CREATE TABLE public.library_user_role (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    library_id uuid NOT NULL,
    user_id uuid NOT NULL,
    agency_role text NOT NULL,
    assigned_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT library_id_fkey FOREIGN KEY (library_id) REFERENCES public.library(id),
    CONSTRAINT agency_role_fkey FOREIGN KEY (agency_role) REFERENCES public.agency_role_enum(value),
    CONSTRAINT user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user(id)
);

CREATE TABLE public.book_on_loan (
    book_id uuid NOT NULL,
    user_id uuid NOT NULL,
    library_id uuid NOT NULL,
    return_deadline timestamp with time zone NOT NULL DEFAULT (NOW() + INTERVAL '30 DAYS'),
    CONSTRAINT book_on_loan_pkey PRIMARY KEY (book_id, user_id),
    CONSTRAINT book_id_fkey FOREIGN KEY (book_id) REFERENCES public.book(id),
    CONSTRAINT user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user(id),
    CONSTRAINT library_id_fkey FOREIGN KEY (library_id) REFERENCES public.library(id)
);

/*
 * Trigger function, called whenever a user becomes a cardholder
 * such that the user also becaomes cardholder in the agency
 * Note that, as this is a minimal example we will not handle deletions
 * of library_user_role (so library cardholder) entries for the sake of 
 * simplicity, but they should be dealt with accordingly in a full system
 */
CREATE OR REPLACE FUNCTION add_agency_user_on_library_user_role_insertion() RETURNS TRIGGER AS $trig$
DECLARE 
    agency_id uuid;
BEGIN
    SELECT library.agency_id INTO agency_id
    FROM library
    WHERE library.id = NEW.library_id;
    
    INSERT INTO agency_user (user_id, agency_id, agency_role) VALUES
    (NEW.user_id, agency_id, NEW.agency_role)
    ON CONFLICT ON CONSTRAINT agency_user_user_id_agency_id_agency_role_key
    DO NOTHING;
RETURN NEW;
END;
$trig$ LANGUAGE plpgsql;

/*
 * Trigger that calls the function that makes sure the user has 
 * an agency_user entry when a librery_user_role is created
 */
CREATE OR REPLACE TRIGGER add_agency_user_on_library_user_role_insertion_trigger 
   AFTER INSERT OR UPDATE OF agency_role
   ON library_user_role
   FOR EACH ROW
       EXECUTE PROCEDURE add_agency_user_on_library_user_role_insertion();

INSERT INTO public.agency (id, name, comment) VALUES
('36f57792-369d-43f9-a81f-6a5dde83fbfa', 'NPLA', 'Netherlands Public Library Association'),
('508b3d68-8b55-490d-9c09-c73a7d06ce09', 'TU/e', 'Eindhoven University of Technology');

INSERT INTO public.book (id, title, author) VALUES
('49be10d4-9dc4-4794-bd8e-e26b58a5868b', 'Invitation to Discrete Mathematics', 'Jiří Matoušek, Jaroslav Nešetřil'),
('1d5d2d61-7520-480f-896d-d6fbce869ea5', 'Introduction to Algorithms', 'T.H. Cormen, C.E. Leiserson, R.L. Rivest and C. Stein'),
('85164824-f77f-43a1-839a-626a385eda72', 'Computational Geometry: Algorithms and Applications', 'M. de Berg, O. Cheong, M. van Kreveld, and M. Overmars'),
('95c166bb-b01b-41c3-9d8e-03ee894c85be', 'Introduction to the Theory of Computation', 'M. Sipser'),
('b2a03bd1-0298-4d43-8899-cc67fd4e6c92', 'Operating System Concepts', 'Abraham Silberschatz, Peter B. Galvin, Greg Gagne');

INSERT INTO public.library (id, name, address, agency_id) VALUES
('508b3d68-8b55-490d-9c09-c73a7d06ce08', 'TU/e Library', 'Eindhoven', '508b3d68-8b55-490d-9c09-c73a7d06ce09'),
('36f57792-369d-43f9-a81f-6a5dde83fffa', 'Utrecht University Library', 'Utrecht', '36f57792-369d-43f9-a81f-6a5dde83fbfa'),
('7a522c64-cd37-4457-acba-cebd00fc1b60', 'University of Amsterdam Library', 'Amsterdam', '36f57792-369d-43f9-a81f-6a5dde83fbfa');

INSERT INTO public.user (id, name, address, email) VALUES
('14b2bbb1-3a86-4521-8722-56b0e8410af0', 'Jane Doe', 'Eindhoven', 'j.doe@student.tue.nl'),
('3a1ab178-9acd-449b-9bef-a729bebd8205', 'John Doe', 'Tilburg', 'j.doe@tilburguniversity.edu'),
('6d6f059e-c879-48a5-bd02-2ef090069469', 'Maria Diaz', 'Rotterdam', 'm.diaz@student.uva.nl'),
('3d2851a6-220b-49f8-8742-d7c8ced44279', 'Jan de Jong', 'Den Haag', 'j.dejong@student.uu.nl'),
('6d6f059e-c879-48a5-bd02-2ef191069469', 'Beth Harmon', 'Amsterdam', 'b.harmon@admin.nl');

INSERT INTO public.book_on_loan (user_id, book_id, library_id) VALUES 
('14b2bbb1-3a86-4521-8722-56b0e8410af0', '49be10d4-9dc4-4794-bd8e-e26b58a5868b', '508b3d68-8b55-490d-9c09-c73a7d06ce08'),
('14b2bbb1-3a86-4521-8722-56b0e8410af0', '1d5d2d61-7520-480f-896d-d6fbce869ea5', '508b3d68-8b55-490d-9c09-c73a7d06ce08'),
('14b2bbb1-3a86-4521-8722-56b0e8410af0', '85164824-f77f-43a1-839a-626a385eda72', '508b3d68-8b55-490d-9c09-c73a7d06ce08'),
('14b2bbb1-3a86-4521-8722-56b0e8410af0', '95c166bb-b01b-41c3-9d8e-03ee894c85be', '508b3d68-8b55-490d-9c09-c73a7d06ce08'),
('14b2bbb1-3a86-4521-8722-56b0e8410af0', 'b2a03bd1-0298-4d43-8899-cc67fd4e6c92', '508b3d68-8b55-490d-9c09-c73a7d06ce08'),
('3a1ab178-9acd-449b-9bef-a729bebd8205', '49be10d4-9dc4-4794-bd8e-e26b58a5868b', '36f57792-369d-43f9-a81f-6a5dde83fffa'),
('3a1ab178-9acd-449b-9bef-a729bebd8205', '85164824-f77f-43a1-839a-626a385eda72', '36f57792-369d-43f9-a81f-6a5dde83fffa'),
('6d6f059e-c879-48a5-bd02-2ef090069469', '1d5d2d61-7520-480f-896d-d6fbce869ea5', '7a522c64-cd37-4457-acba-cebd00fc1b60'),
('6d6f059e-c879-48a5-bd02-2ef090069469', '95c166bb-b01b-41c3-9d8e-03ee894c85be', '7a522c64-cd37-4457-acba-cebd00fc1b60'),
('6d6f059e-c879-48a5-bd02-2ef090069469', 'b2a03bd1-0298-4d43-8899-cc67fd4e6c92', '7a522c64-cd37-4457-acba-cebd00fc1b60'), 
('3d2851a6-220b-49f8-8742-d7c8ced44279', '49be10d4-9dc4-4794-bd8e-e26b58a5868b', '36f57792-369d-43f9-a81f-6a5dde83fffa'),
('3d2851a6-220b-49f8-8742-d7c8ced44279', '95c166bb-b01b-41c3-9d8e-03ee894c85be', '36f57792-369d-43f9-a81f-6a5dde83fffa'),
('3d2851a6-220b-49f8-8742-d7c8ced44279', '85164824-f77f-43a1-839a-626a385eda72', '36f57792-369d-43f9-a81f-6a5dde83fffa');

INSERT INTO public.library_book (library_id, book_id) VALUES
('508b3d68-8b55-490d-9c09-c73a7d06ce08', '49be10d4-9dc4-4794-bd8e-e26b58a5868b'),
('508b3d68-8b55-490d-9c09-c73a7d06ce08', '1d5d2d61-7520-480f-896d-d6fbce869ea5'),
('508b3d68-8b55-490d-9c09-c73a7d06ce08', '85164824-f77f-43a1-839a-626a385eda72'),
('508b3d68-8b55-490d-9c09-c73a7d06ce08', '95c166bb-b01b-41c3-9d8e-03ee894c85be'),
('508b3d68-8b55-490d-9c09-c73a7d06ce08', 'b2a03bd1-0298-4d43-8899-cc67fd4e6c92'),
('36f57792-369d-43f9-a81f-6a5dde83fffa', '49be10d4-9dc4-4794-bd8e-e26b58a5868b'),
('36f57792-369d-43f9-a81f-6a5dde83fffa', '85164824-f77f-43a1-839a-626a385eda72'),
('36f57792-369d-43f9-a81f-6a5dde83fffa', '95c166bb-b01b-41c3-9d8e-03ee894c85be'),
('7a522c64-cd37-4457-acba-cebd00fc1b60', '49be10d4-9dc4-4794-bd8e-e26b58a5868b'),
('7a522c64-cd37-4457-acba-cebd00fc1b60', '1d5d2d61-7520-480f-896d-d6fbce869ea5'),
('7a522c64-cd37-4457-acba-cebd00fc1b60', '95c166bb-b01b-41c3-9d8e-03ee894c85be'),
('7a522c64-cd37-4457-acba-cebd00fc1b60', 'b2a03bd1-0298-4d43-8899-cc67fd4e6c92');

INSERT INTO public.library_user_role (library_id, user_id, agency_role) VALUES
('508b3d68-8b55-490d-9c09-c73a7d06ce08', '14b2bbb1-3a86-4521-8722-56b0e8410af0', 'cardholder'),
('36f57792-369d-43f9-a81f-6a5dde83fffa', '14b2bbb1-3a86-4521-8722-56b0e8410af0', 'cardholder'),
('7a522c64-cd37-4457-acba-cebd00fc1b60', '14b2bbb1-3a86-4521-8722-56b0e8410af0', 'cardholder'),
('36f57792-369d-43f9-a81f-6a5dde83fffa', '3a1ab178-9acd-449b-9bef-a729bebd8205', 'cardholder'),
('36f57792-369d-43f9-a81f-6a5dde83fffa', '3d2851a6-220b-49f8-8742-d7c8ced44279', 'cardholder'),
('7a522c64-cd37-4457-acba-cebd00fc1b60', '6d6f059e-c879-48a5-bd02-2ef090069469', 'cardholder');

INSERT INTO public.agency_user (user_id, agency_id, agency_role) VALUES
('6d6f059e-c879-48a5-bd02-2ef191069469', '36f57792-369d-43f9-a81f-6a5dde83fbfa', 'agency_admin');