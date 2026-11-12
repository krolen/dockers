# Aegra on the NAS

The [`Dockerfile`](Dockerfile) downloads Aegra source from GitHub for the
release tag in `AEGRA_REF` and builds the image from that source. It does not
automatically select the newest release. To upgrade, check
[Aegra releases](https://github.com/aegra/aegra/releases), set `AEGRA_REF` to
the newest stable release tag, then build and publish with:

```sh
./push_to_hub.sh aegra latest
```

Run [`docker-compose.yml`](docker-compose.yml) on the NAS. It uses
`kkulagin/aegra:latest`, runs database migrations before starting the API, and
mounts these existing NAS paths:

| NAS path | Container path | Purpose |
| --- | --- | --- |
| `/mnt/MyPool/myapps/nfs/aegra/agents` | `/app/agents` | Custom agent code |
| `/mnt/MyPool/myapps/nfs/aegra/aegra.json` | `/app/aegra.json` | Custom graph configuration |

The NAS `aegra.json` must exist as a file before starting the container.
The bind mount hides the example config packaged in the image, so updating the
image does not replace the NAS config or agent files. Any additional Python
packages required by custom agents need to be included in the image.

Set the database connection and any API keys through Compose environment
variables or a NAS environment file. The Compose defaults for passwords and
keys are placeholders. `AUTH_TYPE=noop` leaves the published API without
authentication; configure access to port 2026 accordingly.
