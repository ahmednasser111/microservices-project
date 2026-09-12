#!/bin/bash
# Runs automatically via the postgres image's docker-entrypoint-initdb.d mechanism on first
# boot (only — it does not re-run against an existing data volume). Creates one database per
# comma-separated name in POSTGRES_MULTIPLE_DATABASES, all owned by POSTGRES_USER, so
# auth-service and chat-service can share one Postgres container while keeping separate
# databases (authdb, chatdb) instead of running two full Postgres instances.
set -e
set -u

create_database() {
	local database=$1
	echo "Creating database '$database'"
	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
		CREATE DATABASE "$database";
	EOSQL
}

if [ -n "${POSTGRES_MULTIPLE_DATABASES:-}" ]; then
	echo "Multiple database creation requested: $POSTGRES_MULTIPLE_DATABASES"
	for db in $(echo "$POSTGRES_MULTIPLE_DATABASES" | tr ',' ' '); do
		create_database "$db"
	done
	echo "Multiple databases created"
fi
