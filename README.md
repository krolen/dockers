# dockers

Docker service definitions for this machine.

## Local data mapping

All container data (profiles, config, state) is stored under `~/docker-data/`
on the host — never inside the service directories. Each service gets its own
subdirectory, so data survives container rebuilds and image updates, and can be
backed up or deleted per service.

The `~/docker-data/` directories are created automatically by Docker on first
`up`. Compose files reference them with a `~/docker-data/<service>` bind
source; Docker Compose expands `~` to the home directory (verified with
`docker compose config` from an arbitrary cwd).

| Service        | Compose file            | Host path            | Container path |
|----------------|-------------------------|----------------------|----------------|
| chrome-stealth | `chrome/docker-compose.yml` | `~/docker-data/chrome/` | `/config` |

## Conventions

- Service directories (`chrome/`, `crawl4ai/`, ...) hold only the compose
  file / Dockerfile and docs; no data.
- Volume mounts from a compose file use a path relative to the user's home
  (`~/docker-data/<service>`), so `docker compose up` works from any cwd and
  data stays outside the repo regardless of where it lives.
- When adding a new service, give it its own `~/docker-data/<service>/`
  directory and a row in the table above.
