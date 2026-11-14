#!/bin/sh
set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$PROJECT_ROOT"

ENGINE=${CONTAINER_ENGINE:-podman}
IMAGE=${RABBITMQ_IMAGE:-docker.io/library/rabbitmq:4-management}
NAME=week3-rabbitmq

if ! command -v "$ENGINE" >/dev/null 2>&1; then
    echo "Container engine missing: $ENGINE. Set CONTAINER_ENGINE=docker to use Docker." >&2
    exit 1
fi
if [ ! -f .env ]; then
    echo "Copy .env.example to .env and choose matching local broker credentials first." >&2
    exit 1
fi

if "$ENGINE" container exists "$NAME" 2>/dev/null; then
    "$ENGINE" start "$NAME" >/dev/null
elif "$ENGINE" container inspect "$NAME" >/dev/null 2>&1; then
    # Docker does not provide 'container exists'.
    "$ENGINE" start "$NAME" >/dev/null
else
    # Initialize ownership before RabbitMQ drops privileges to its service user.
    "$ENGINE" run --rm --user 0 --entrypoint sh \
        --volume week3-rabbitmq-data:/var/lib/rabbitmq \
        "$IMAGE" -c 'chown -R rabbitmq:rabbitmq /var/lib/rabbitmq'
    "$ENGINE" run --detach --name "$NAME" --hostname "$NAME" \
        --env-file .env \
        --publish 127.0.0.1:5672:5672 \
        --publish 127.0.0.1:15672:15672 \
        --volume week3-rabbitmq-data:/var/lib/rabbitmq \
        "$IMAGE" >/dev/null
fi

echo "Waiting for RabbitMQ..."
attempt=0
until "$ENGINE" exec "$NAME" rabbitmq-diagnostics -q check_running >/dev/null 2>&1; do
    if [ "$("$ENGINE" inspect --format '{{.State.Running}}' "$NAME")" != true ]; then
        echo "RabbitMQ exited. Inspect: $ENGINE logs $NAME" >&2
        exit 1
    fi
    attempt=$((attempt + 1))
    if [ "$attempt" -ge 45 ]; then
        echo "RabbitMQ did not become ready. Inspect: $ENGINE logs $NAME" >&2
        exit 1
    fi
    sleep 2
done

"$ENGINE" cp infra/definitions.json "$NAME":/tmp/image-definitions.json
"$ENGINE" exec "$NAME" rabbitmqctl import_definitions /tmp/image-definitions.json
echo "Broker ready. Management: http://localhost:15672"
echo "Use RABBITMQ_DEFAULT_USER and RABBITMQ_DEFAULT_PASS from your local .env."
