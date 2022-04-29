CREATE OR REPLACE VIEW "public"."acl_library" AS 
SELECT library.id,
    agency_user.user_id AS user_id,
    'read'::text AS access
  FROM agency_user, agency, library
  WHERE ((agency_user.agency_role = 'agency_admin')
    AND (agency_user.agency_id = agency.id)
    AND (agency.id = library.agency_id));
