# ritchie

Minimal notes for the `ritchie` server.

## Connection

- Host: `ritchie.tonioriol.com`
- IP: `188.226.140.165`
- SSH user: `forge`
- SSH port: `22`
- Auth: `publickey` (password auth disabled)

### Default (main key)

```bash
ssh forge@ritchie.tonioriol.com
```

### Force a specific local key (fallback)

```bash
ssh -i /Users/tr0n/.ssh/id_rsa_2 -o IdentitiesOnly=yes forge@ritchie.tonioriol.com
```

## Users

Home directories under `/home`:

- `forge` (uid 1000, shell `/bin/bash`)
- `syslog` (uid 104, shell `/bin/false`)

## Credentials source of truth

Non-secret connection metadata is stored in 1Password item **“ritchie”** (category: Server, vault: Private).

## Notes

- The server is running **Ubuntu 16.04** (legacy). Be cautious with upgrades/changes.
