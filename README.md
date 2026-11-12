# dockers

Docker service definitions for this machine.

## Local data mapping

Local container data (profiles, config, state) is stored under `~/docker-data/`
on the host — never inside the service directories. Each local service gets its
own subdirectory, so data survives container rebuilds and image updates.
Aegra is deployed on a NAS and uses its NAS paths instead; see
[`aegra/README.md`](aegra/README.md).

The `~/docker-data/` directories are created automatically by Docker on first
`up`. Local Compose files reference them with a `~/docker-data/<service>` bind
source; Docker Compose expands `~` to the home directory.

| Service        | Compose file            | Host path            | Container path |
|----------------|-------------------------|----------------------|----------------|
| chrome-stealth | `chrome/docker-compose.yml` | `~/docker-data/chrome/` | `/config` |

## Conventions

- Service directories (`chrome/`, `crawl4ai/`, ...) hold only the compose
  file / Dockerfile and docs; no data.
- Local volume mounts use a path relative to the user's home
  (`~/docker-data/<service>`). NAS deployments use their actual host paths.
- When adding a new local service, give it its own `~/docker-data/<service>/`
  directory and a row in the table above.
