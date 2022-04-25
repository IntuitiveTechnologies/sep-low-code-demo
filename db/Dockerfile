FROM postgres:14 as db
# Seed data: https://dev.to/karanpratapsingh/seeding-postgres-with-docker-19n7
COPY --chown=postgres:postgres ./db/fixtures/entry /docker-entrypoint-initdb.d