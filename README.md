# Nagios Core Docker

This repo builds a clean Ubuntu-based Nagios Core image and exposes the standard Nagios directories directly on the host.

## Layout

- `docker/` contains the generic image assets that ship with Nagios.
- `etc/` contains the editable Nagios configuration, including `nagios.cfg`, `resource.cfg`, and `objects/`.
- `libexec/` contains custom check scripts and helper executables.
- `var/` contains Nagios runtime state and logs.


## Quick start

For local development:

```bash
docker compose up -d --build
```

Then open:

```text
http://localhost:8080/
```

The web UI credentials live in `etc/htpasswd.users`.
The example ships with a default `nagiosadmin` user, and you should change the
password in that file before using it for anything real.
If you want to add another user later, you will also need to add that user to
the `authorized_for_*` entries in `cgi.cfg`.

If you use `.env.example`, copy it to `.env` first and adjust the non-auth
values you need.

If Nagios sits behind an ALB or any TLS terminator, set `NAGIOS_FORCE_SSL=true`
so the container trusts `X-Forwarded-Proto` and upgrades insecure browser
requests.

Set `TZ` in `.env` if you want Nagios to show timestamps in your local zone,
for example `UTC`.



## Use The Image

The published image is:

```text
ghcr.io/jrafaelca/nagios:latest
```

Use it from your own Compose file in production. A minimal example:

```yaml
services:
  nagios:
    image: ghcr.io/jrafaelca/nagios:latest
    restart: unless-stopped
    env_file: .env
    ports:
      - "8080:80"
    volumes:
      - ./etc:/usr/local/nagios/etc
      - ./libexec:/usr/local/nagios/libexec
      - ./var:/usr/local/nagios/var
```

## What lives where

- Generic runtime wiring ships in the image under `docker/nagios/`
- The editable starting config lives in `etc/`
- Custom scripts live in `libexec/`
- Runtime state and logs live in `var/`

On first boot the container seeds `cgi.cfg` and `htpasswd.users` under `etc/`
if they do not exist yet, so the host copy stays visible and editable.
The `cgi.cfg` file is generated with `nagiosadmin` as the authorized user.

To change the password, generate a new line and replace the existing one:

```bash
htpasswd -nbB nagiosadmin 'your-password' > etc/htpasswd.users
```

## Image Env Vars

The container reads these environment variables:

| Variable | Purpose |
| --- | --- |
| `NAGIOS_FORCE_SSL` | Set to `true` when TLS is terminated upstream so Apache adds HTTPS-aware headers. |
| `TZ` | Container timezone used by Nagios logs and timestamps. |

Compose-only variables:

| Variable | Purpose |
| --- | --- |
| `FORWARD_PORT` | Host port published to container port `80` for local development. |
