#!/bin/sh
set -e

export IN_DOCKER=1
cd /app

alembic upgrade head

exec "$@"
