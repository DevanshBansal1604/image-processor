# Image Processor

A Python image-processing project built incrementally with FastAPI and RabbitMQ.

## Progress

Day 1 foundation: API liveness, configuration, upload directory creation, local RabbitMQ topology, and a validated version 1 job-ticket contract.

The upload endpoint, API publisher, and worker are not implemented yet. An empty queue is expected.

## Local setup

Use Python 3.11 or later. The container commands use Podman, matching the URL shortener project. Docker also works with `CONTAINER_ENGINE=docker sh scripts/start_broker.sh`.

Run from the project root:

```sh
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
cp .env.example .env
```

Choose a local password in `.env`. Set `RABBITMQ_DEFAULT_PASS` and the password in `RABBITMQ_URL` to the same value. Use a URL-safe password or URL-encode it in the connection URL. Never commit `.env`.

The initial setup on the author's laptop already has a generated local password and an installed virtual environment. Do not overwrite that `.env` when resuming.

Environment variables override `.env`; unspecified settings use code defaults. Relative `STORAGE_ROOT` paths resolve against the project root. Broker names in `.env` must match `infra/definitions.json`; changing one does not rename existing broker resources.

### Start RabbitMQ

On macOS, ensure the Podman machine is running (`podman machine start` if stopped). Then:

```sh
sh scripts/start_broker.sh
```

The script initializes ownership in its dedicated data volume, creates or starts `week3-rabbitmq`, waits for broker startup, and imports `infra/definitions.json`. It leaves other containers untouched. It can be run again to restore the declared topology.

If Docker Hub's download endpoint fails certificate verification on this machine, use its Google-hosted mirror without disabling TLS verification:

```sh
RABBITMQ_IMAGE=mirror.gcr.io/library/rabbitmq:4-management sh scripts/start_broker.sh
```

The image override is used only when creating the container; subsequent runs start the existing container.

Management interface: [localhost:15672](http://localhost:15672). Log in using `RABBITMQ_DEFAULT_USER` and `RABBITMQ_DEFAULT_PASS` from your local `.env`.

Messaging clients connect on port **5672**. The management interface uses **15672**. Both are exposed only on the local machine.

The named volume `week3-rabbitmq-data` stores broker data. Do not remove it if you want to retain jobs and definitions. Editing `.env` does not change a user password already initialized in this volume.

### Start the API

In a second terminal, from the project root:

```sh
source .venv/bin/activate
python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8001
```

Port 8001 avoids conflicting with the URL shortener's usual port 8000.

- [Health](http://localhost:8001/health): returns `{"status":"ok"}`.
- [Interactive API docs](http://localhost:8001/docs).
- [OpenAPI document](http://localhost:8001/openapi.json).

Startup creates `storage/uploads/` (or the configured equivalent). Failure to create it fails startup. `/health` checks API liveness only; Day 1 does not connect the API to RabbitMQ.

### Inspect the broker

In the management UI, choose virtual host `/` and inspect Exchanges, Queues and Streams, and the exchange's bindings. Or run:

```sh
podman exec week3-rabbitmq rabbitmqctl list_exchanges name type durable
podman exec week3-rabbitmq rabbitmqctl list_queues name durable messages consumers
podman exec week3-rabbitmq rabbitmqctl list_bindings source_name destination_name routing_key
```

Expected topology:

| Role | Component |
| --- | --- |
| Producer | Future FastAPI publisher |
| Exchange | `image-exchange`, direct, durable |
| Binding key | `image.process` |
| Queue | `image-jobs`, classic, durable, no auto-delete |
| Consumer | Future Week 4 image worker |

A message published to `image-exchange` with routing key `image.process` matches the queue binding exactly. Workers consuming the same queue share jobs; RabbitMQ does not select a worker based on the operation inside JSON.

To stop the broker:

```sh
podman stop week3-rabbitmq
```

Stop the API with Ctrl+C in its terminal. Durability preserves queue definitions across broker restarts. Persistent messages and publisher confirms will be added with publishing; durability alone does not guarantee message survival.

## Job-ticket contract

The example is in `examples/image-job.json`; its referenced file is illustrative and does not exist yet.

```json
{
  "schema_version": 1,
  "job_id": "3a42eef9-a1f6-4405-a091-f784433e2a59",
  "stored_file": "uploads/3a42eef9-a1f6-4405-a091-f784433e2a59.jpg",
  "content_type": "image/jpeg",
  "operation": {"name": "resize", "width": 800, "height": 600}
}
```

`app/schemas.py` validates the contract: version 1, a UUID job ID, a relative POSIX file reference without traversal, a JPEG/PNG/WebP content type, and a resize operation with positive integer dimensions. Additional fields are rejected. This validates a ticket's structure, not file existence or the actual image bytes. Image-content validation comes on Day 2.

`stored_file` is relative to `STORAGE_ROOT`. The API and future worker must access the same stored file, potentially through different local mount points. The ticket contains a reference, not image bytes. Storage security and atomic writes will be implemented with the upload service.

Validate and serialize the example:

```sh
python -c 'from pathlib import Path; from app.schemas import ImageJob; job = ImageJob.model_validate_json(Path("examples/image-job.json").read_text()); print(job.model_dump_json(indent=2))'
```

## Intended acceptance flow

1. API receives and validates an upload.
2. API finalizes the saved file.
3. API publishes its JSON ticket through the exchange into the queue.
4. Only after confirmed publishing with unroutable-message detection does the API return `202 Accepted` with `job_id`.
5. A future worker consumes the ticket, opens the saved image, and processes it.

Only the foundation exists today. Publisher confirms acknowledge broker responsibility, not completed processing. Consumer acknowledgements are separate. UI job-status tracking requires additional implementation. Publish timeouts can leave acceptance uncertain; failure handling is planned for Day 5.

## Module map

| File | Responsibility |
| --- | --- |
| `app/config.py` | Typed settings, local `.env`, storage paths |
| `app/main.py` | FastAPI application, startup directory, `/health` |
| `app/schemas.py` | Version 1 ticket and resize-operation contracts |
| `infra/definitions.json` | Exchange, queue, and binding declarations |
| `scripts/start_broker.sh` | Start broker and import topology |
| `examples/image-job.json` | Example ticket |
| `requirements.txt` | Direct Python dependencies |

The dependencies are pinned directly; this is not a complete transitive lockfile.

## Learning milestones and commits

- Day 1: API foundation, configuration, storage directory, RabbitMQ topology, and ticket contract.
- Day 2: Upload endpoint and input validation.
- Day 3: Safe storage and shared resource lifecycle.
- Day 4: Confirmed publishing and 202 acceptance.
- Day 5: Broker failures and acceptance boundaries.
- Day 6: Automated integration verification and documentation.
- Day 7: Guided code and test walkthrough.
- Week 4: Image-processing worker.

Implement one learning day's scope at a time. Commit verified work at the end of each learning day or at a meaningful smaller milestone, using descriptive messages. Keep actual commit dates; milestone numbers do not imply calendar dates. Keep credentials, virtual environments, service data, and uploads out of Git.

## References

- [FastAPI lifespan](https://fastapi.tiangolo.com/advanced/events/)
- [Pydantic settings](https://docs.pydantic.dev/latest/concepts/pydantic_settings/)
- [RabbitMQ exchanges and bindings](https://www.rabbitmq.com/docs/exchanges)
- [RabbitMQ definitions import](https://www.rabbitmq.com/docs/definitions)
