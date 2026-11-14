# Image Processor

A Python image-processing project built incrementally while learning FastAPI and RabbitMQ.

## Current progress

Repository initialized. Application setup and implementation have not started.

## Intended flow

1. FastAPI validates and saves an uploaded image.
2. The API publishes a JSON job ticket containing a relative file reference.
3. RabbitMQ routes the ticket through `image-exchange` (direct), using routing key `image.process`, to the durable `image-jobs` queue.
4. After safe storage and confirmed publishing with unroutable-message detection, the API returns `202 Accepted` with a job ID.
5. A future worker reads the ticket, accesses the saved image, and performs the requested operation.

The API and worker must be able to access the same stored files. Acceptance does not mean processing has completed.

## Week 3 milestones

- Day 1: Python environment, FastAPI foundation, configuration, upload directory, local RabbitMQ, routing, and job-ticket contract.
- Day 2: Upload endpoint and input validation.
- Day 3: Safe file storage and resource lifecycle.
- Day 4: Confirmed job publishing and the 202 response.
- Day 5: Broker failures and acceptance boundaries.
- Day 6: Integration verification and documentation.
- Day 7: Guided code and test walkthrough.

Image processing workers are planned for Week 4.

## Commit workflow

- Implement and explain one day's scope at a time.
- Commit completed, verified work at the end of each learning day, or at a smaller meaningful milestone.
- Use descriptive messages such as `Day 1: set up FastAPI and local RabbitMQ`.
- Keep commits dated when the work actually happens; learning-day numbers are milestones, not calendar dates.
- Update progress and run instructions as features become available.
- Never commit credentials, local environment files, virtual environments, or uploaded images.
