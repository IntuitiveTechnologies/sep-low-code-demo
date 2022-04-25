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

CREATE TABLE public.demo (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    title character varying(100) NOT NULL,
    description character varying,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT demo_pkey PRIMARY KEY (id),
    UNIQUE(title),
    CONSTRAINT only_chars_and_numbers_in_key CHECK(title ~ '^[a-zA-Z0-9_\-]{2,}$')
);

CREATE TRIGGER clean_keys
               BEFORE INSERT
               ON public.demo
               FOR EACH ROW
               EXECUTE FUNCTION public.clean_keys();

DROP TRIGGER IF EXISTS set_public_demo_updated_at ON public.demo;

CREATE TRIGGER set_public_demo_updated_at BEFORE
UPDATE
  ON public.demo FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();

---
--- DATABASE DUMP FROM 13-04-2022
---
INSERT INTO public.demo (title, description) VALUES ('Title_1', 'Description 1');

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

CREATE TABLE public.library (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    name character varying(100) NOT NULL,
    address character varying,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT library_pkey PRIMARY KEY (id),
    UNIQUE(name),
    CONSTRAINT only_chars_and_numbers_in_library_name CHECK(name ~ '^[a-zA-Z0-9\-\/ ]{2,}$'),
    CONSTRAINT only_chars_and_numbers_in_library_address CHECK(address ~ '^[a-zA-Z0-9\- ]{2,}$')
);

CREATE TABLE public.cardholder (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    name character varying(100) NOT NULL,
    address character varying,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT cardholder_pkey PRIMARY KEY (id),
    CONSTRAINT only_chars_in_cardholder_name CHECK(name ~ '^[a-zA-Z _\-]{2,}$'),
    CONSTRAINT only_chars_and_numbers_in_cardholder_address CHECK(address ~ '^[a-zA-Z0-9\- ]{2,}$')
);

CREATE TABLE public.library_book (
    library_id uuid NOT NULL,
    book_id uuid NOT NULL,
    CONSTRAINT library_book_pkey PRIMARY KEY (library_id, book_id),
    CONSTRAINT library_id_fkey FOREIGN KEY (library_id) REFERENCES public.library(id),
    CONSTRAINT book_id_fkey FOREIGN KEY (book_id) REFERENCES public.book(id)
);

CREATE TABLE public.library_cardholder (
    library_id uuid NOT NULL,
    cardholder_id uuid NOT NULL,
    CONSTRAINT library_cardholder_pkey PRIMARY KEY (library_id, cardholder_id),
    CONSTRAINT library_id_fkey FOREIGN KEY (library_id) REFERENCES public.library(id),
    CONSTRAINT cardholder_id_fkey FOREIGN KEY (cardholder_id) REFERENCES public.cardholder(id)
);

CREATE TABLE public.book_on_loan (
    book_id uuid NOT NULL,
    cardholder_id uuid NOT NULL,
    return_deadline timestamp with time zone NOT NULL DEFAULT (NOW() + INTERVAL '30 DAYS'),
    CONSTRAINT book_on_loan_pkey PRIMARY KEY (book_id, cardholder_id),
    CONSTRAINT book_id_fkey FOREIGN KEY (book_id) REFERENCES public.book(id),
    CONSTRAINT cardholder_id_fkey FOREIGN KEY (cardholder_id) REFERENCES public.cardholder(id)
);


INSERT INTO public.book (id, title, author) VALUES
('49be10d4-9dc4-4794-bd8e-e26b58a5868b', 'Invitation to Discrete Mathematics', 'Jiří Matoušek, Jaroslav Nešetřil'),
('1d5d2d61-7520-480f-896d-d6fbce869ea5', 'Introduction to Algorithms', 'T.H. Cormen, C.E. Leiserson, R.L. Rivest and C. Stein'),
('85164824-f77f-43a1-839a-626a385eda72', 'Computational Geometry: Algorithms and Applications', 'M. de Berg, O. Cheong, M. van Kreveld, and M. Overmars'),
('95c166bb-b01b-41c3-9d8e-03ee894c85be', 'Introduction to the Theory of Computation', 'M. Sipser'),
('b2a03bd1-0298-4d43-8899-cc67fd4e6c92', 'Operating System Concepts', 'Abraham Silberschatz, Peter B. Galvin, Greg Gagne');

INSERT INTO public.library (id, name, address) VALUES
('508b3d68-8b55-490d-9c09-c73a7d06ce08', 'TU/e Library', 'Eindhoven'),
('36f57792-369d-43f9-a81f-6a5dde83fffa', 'Utrecht University Library', 'Utrecht'),
('7a522c64-cd37-4457-acba-cebd00fc1b60', 'University of Amsterdam Library', 'Amsterdam');

INSERT INTO public.cardholder (id, name, address) VALUES
('14b2bbb1-3a86-4521-8722-56b0e8410af0', 'Jane Doe', 'Eindhoven'),
('3a1ab178-9acd-449b-9bef-a729bebd8205', 'John Doe', 'Tilburg'),
('6d6f059e-c879-48a5-bd02-2ef090069469', 'Maria Diaz', 'Rotterdam'),
('3d2851a6-220b-49f8-8742-d7c8ced44279', 'Jan de Jong', 'Den Haag');

INSERT INTO public.book_on_loan (cardholder_id, book_id) VALUES 
('14b2bbb1-3a86-4521-8722-56b0e8410af0', '49be10d4-9dc4-4794-bd8e-e26b58a5868b'),
('14b2bbb1-3a86-4521-8722-56b0e8410af0', '1d5d2d61-7520-480f-896d-d6fbce869ea5'),
('14b2bbb1-3a86-4521-8722-56b0e8410af0', '85164824-f77f-43a1-839a-626a385eda72'),
('14b2bbb1-3a86-4521-8722-56b0e8410af0', '95c166bb-b01b-41c3-9d8e-03ee894c85be'),
('14b2bbb1-3a86-4521-8722-56b0e8410af0', 'b2a03bd1-0298-4d43-8899-cc67fd4e6c92'),
('3a1ab178-9acd-449b-9bef-a729bebd8205', '49be10d4-9dc4-4794-bd8e-e26b58a5868b'),
('3a1ab178-9acd-449b-9bef-a729bebd8205', '85164824-f77f-43a1-839a-626a385eda72'),
('6d6f059e-c879-48a5-bd02-2ef090069469', '1d5d2d61-7520-480f-896d-d6fbce869ea5'),
('6d6f059e-c879-48a5-bd02-2ef090069469', '95c166bb-b01b-41c3-9d8e-03ee894c85be'),
('6d6f059e-c879-48a5-bd02-2ef090069469', 'b2a03bd1-0298-4d43-8899-cc67fd4e6c92'), 
('3d2851a6-220b-49f8-8742-d7c8ced44279', '49be10d4-9dc4-4794-bd8e-e26b58a5868b'),
('3d2851a6-220b-49f8-8742-d7c8ced44279', '95c166bb-b01b-41c3-9d8e-03ee894c85be'),
('3d2851a6-220b-49f8-8742-d7c8ced44279', '85164824-f77f-43a1-839a-626a385eda72');

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

INSERT INTO public.library_cardholder (library_id, cardholder_id) VALUES
('508b3d68-8b55-490d-9c09-c73a7d06ce08', '14b2bbb1-3a86-4521-8722-56b0e8410af0'),
('36f57792-369d-43f9-a81f-6a5dde83fffa', '3a1ab178-9acd-449b-9bef-a729bebd8205'),
('36f57792-369d-43f9-a81f-6a5dde83fffa', '3d2851a6-220b-49f8-8742-d7c8ced44279'),
('7a522c64-cd37-4457-acba-cebd00fc1b60', '6d6f059e-c879-48a5-bd02-2ef090069469');