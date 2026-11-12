# Requirements Document

## Introduction

The Tiko platform runs three Spring Boot business services — `queue-service`, `appointment-service`, and `profile-notification-service` — behind an `api-gateway` in Docker Compose. Each service already exposes `/actuator/health` via Spring Actuator, and each Dockerfile already defines a `HEALTHCHECK` instruction that probes that endpoint. The `api-gateway` has `depends_on` conditions of `service_healthy` on all three, which are therefore already meaningful.

The problem is that healthcheck timing and probe configuration are buried inside three separate Dockerfiles. Any developer reading `docker-compose.yml` to understand startup behaviour cannot see the probe parameters there. This item centralizes the healthcheck stanzas in `docker-compose.yml` — a Compose-level stanza overrides the Dockerfile-level `HEALTHCHECK`, making timing visible and controlled in one place alongside the rest of the service definitions.

This feature adds a `healthcheck` stanza to each of the three business services in `docker-compose.yml`, enforces required environment variables using `${VAR:?message}` syntax, adds a static verification script, and updates the README with the canonical startup command. No application code changes, no new technologies, and no restructuring of existing services are required.

## Glossary

- **Compose_Stack**: The set of Docker containers defined in `docker-compose.yml` at the repository root.
- **Business_Service**: Any of the three Spring Boot containers — `queue-service` (port 8081), `appointment-service` (port 8082), or `profile-notification-service` (port 8083).
- **Health_Endpoint**: The HTTP endpoint `/actuator/health` exposed by each Business_Service via Spring Actuator.
- **Healthcheck_Stanza**: The `healthcheck` block within a Docker Compose service definition that Docker uses to determine container readiness.
- **Gateway**: The `api-gateway` container that routes authenticated requests to the Business_Services.
- **depends_on**: The Docker Compose directive that delays a container's startup until its dependency reaches a specified condition.
- **README**: The file `README.md` at the repository root.
- **Env_File**: The file `.env` at the repository root, created by the developer by copying `.env.example` before first run.
- **Env_Example**: The file `.env.example` at the repository root, committed to the repository, listing every required variable with placeholder values.
- **Required_Variable**: Any environment variable consumed by `docker-compose.yml` whose absence would cause a service to start incorrectly or silently — specifically: `KC_ADMIN`, `KC_ADMIN_PASSWORD`, `POSTGRES_SUPERUSER`, `POSTGRES_SUPERUSER_PASSWORD`, `QUEUE_DB_NAME`, `QUEUE_DB_USER`, `QUEUE_DB_PASSWORD`, `APPOINTMENTS_DB_NAME`, `APPOINTMENTS_DB_USER`, `APPOINTMENTS_DB_PASSWORD`, `PROFILES_DB_NAME`, `PROFILES_DB_USER`, `PROFILES_DB_PASSWORD`, `TIKO_CLIENT_PASSWORD`, `TIKO_AGENT_PASSWORD`, `TIKO_ADMIN_PASSWORD`, `KEYCLOAK_PORT`, `GATEWAY_PORT`, `FRONTEND_PORT`, and `FRONTEND_DEV_PORT`.
- **Verification_Script**: The shell script `scripts/check-compose-healthchecks.sh` at the repository root that performs a static check of `docker compose --env-file .env.example config` output, allowing it to run on a fresh clone and in CI without a real `.env` file.

---

## Requirements

### Requirement 1: Docker Healthcheck Stanzas for Business Services

**User Story:** As a developer, I want each Business_Service to have a Healthcheck_Stanza in `docker-compose.yml`, so that Docker can determine actual container readiness before the Gateway starts routing traffic.

#### Acceptance Criteria

1. WHEN `docker-compose.yml` is inspected, THE `queue-service` service definition SHALL contain a `healthcheck` stanza with `test: ["CMD-SHELL", "wget -qO- http://127.0.0.1:8081/actuator/health | grep -q UP || exit 1"]`, `interval: 10s`, `timeout: 3s`, `retries: 6`, and `start_period: 60s`.

2. WHEN `docker-compose.yml` is inspected, THE `appointment-service` service definition SHALL contain a `healthcheck` stanza with `test: ["CMD-SHELL", "wget -qO- http://127.0.0.1:8082/actuator/health | grep -q UP || exit 1"]`, `interval: 10s`, `timeout: 3s`, `retries: 6`, and `start_period: 60s`.

3. WHEN `docker-compose.yml` is inspected, THE `profile-notification-service` service definition SHALL contain a `healthcheck` stanza with `test: ["CMD-SHELL", "wget -qO- http://127.0.0.1:8083/actuator/health | grep -q UP || exit 1"]`, `interval: 10s`, `timeout: 3s`, `retries: 6`, and `start_period: 60s`.

4. WHEN the Compose_Stack is started, THE Docker_Engine SHALL report each Business_Service as `healthy` only after `wget -qO- http://127.0.0.1:808x/actuator/health | grep -q UP` returns exit code 0 for that service's port, confirming the response body contains the string `UP`.

5. IF a Business_Service does not respond to the health probe within the configured `timeout`, THEN THE Docker_Engine SHALL count that attempt as a failed check and retry up to `retries` times before marking the container `unhealthy`.

6. WHEN both a Dockerfile-level `HEALTHCHECK` and a Compose-level `healthcheck` stanza are present for the same Business_Service, THE Docker_Engine SHALL use the Compose-level stanza and ignore the Dockerfile-level instruction.

---

### Requirement 2: Gateway Startup Ordering Enforced by Real Healthchecks

**User Story:** As a developer, I want the Gateway to start only after all three Business_Services are genuinely healthy, so that the Gateway does not route requests to services that are not yet ready.

#### Acceptance Criteria

1. WHEN `docker-compose.yml` is inspected, THE `api-gateway` service definition SHALL retain `depends_on` entries for `queue-service`, `appointment-service`, and `profile-notification-service`, each with `condition: service_healthy`.

2. WHEN the Compose_Stack is started and a Business_Service has not yet reached the `healthy` state, THE Docker_Engine SHALL keep the Gateway container in the waiting state rather than starting it.

3. WHEN all three Business_Services report `healthy`, THE Docker_Engine SHALL proceed to start the Gateway container.

---

### Requirement 3: Single-Command Startup with Environment Variable Enforcement

**User Story:** As a developer, I want to bring the entire Tiko stack up with one terminal command after copying `.env.example` to `.env`, so that onboarding and local development require no manual orchestration steps beyond setting credentials.

#### Acceptance Criteria

1. THE Env_Example file SHALL be committed to the repository and SHALL contain an entry for every Required_Variable with a non-empty placeholder value.

2. WHEN `docker-compose.yml` is inspected, THE Compose_Stack definition SHALL reference every Required_Variable using `${VAR:?error message}` syntax rather than plain `${VAR}` syntax.

3. WHEN a developer runs `docker compose config` or `docker compose up` with one or more Required_Variables absent from the environment, THE Docker_Engine SHALL exit immediately with a non-zero status code and a descriptive error message naming the missing variable.

4. WHEN a developer runs `cp .env.example .env` followed by filling in real credentials and then `docker compose up` from the repository root, THE Compose_Stack SHALL start all services — including Keycloak, PostgreSQL, the three Business_Services, the Gateway, and the frontend — without requiring any additional commands.

5. WHEN `docker compose up` completes successfully, THE frontend SHALL be reachable at `http://localhost:<FRONTEND_PORT>` and the Gateway SHALL be reachable at `http://localhost:<GATEWAY_PORT>`.

---

### Requirement 4: README Documents the Startup Command

**User Story:** As a developer new to the project, I want the README to document the canonical startup command, so that I can run the full stack without reading the full Compose configuration.

#### Acceptance Criteria

1. WHEN the README is inspected, THE README SHALL contain the command `docker compose up --build` in a fenced code block within the "Run locally" section.

2. THE README SHALL describe that `docker compose up` starts all services including Keycloak, PostgreSQL, the three Business_Services, the Gateway, and the frontend.

---

### Requirement 5: Static Healthcheck Verification Script

**User Story:** As a developer, I want a script that statically verifies every service with a `service_healthy` dependency also defines a healthcheck, so that configuration drift is caught before the stack is started.

#### Acceptance Criteria

1. WHEN the repository is inspected, THE repository SHALL contain the Verification_Script at `scripts/check-compose-healthchecks.sh` with no more than 30 lines of shell code.

2. WHEN the Verification_Script is executed, THE Verification_Script SHALL run `docker compose --env-file .env.example config` against the `docker-compose.yml` at the repository root and parse the output to identify every service listed as a `condition: service_healthy` dependency, so that the script works on a fresh clone and in CI without a real `.env` file.

3. WHEN the Verification_Script identifies a service listed as a `condition: service_healthy` dependency and that service does NOT have a `healthcheck` block in the `docker compose config` output, THE Verification_Script SHALL print a descriptive error message naming the offending service and exit with status code 1.

4. WHEN every service listed as a `condition: service_healthy` dependency has a `healthcheck` block present in the `docker compose config` output, THE Verification_Script SHALL print a success message and exit with status code 0.

5. THE Verification_Script SHALL perform only static analysis of the Compose configuration and SHALL NOT start, stop, or connect to any container or external service.
