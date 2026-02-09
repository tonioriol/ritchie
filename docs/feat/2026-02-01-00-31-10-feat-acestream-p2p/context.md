# feat-acestream-p2p AceStream: improve inbound connectivity (P2P ports)

## TASK

Improve inbound connectivity for AceStream playback by ensuring peers can connect back to the AceStream engine (expose the required P2P/control ports on the node and open the Hetzner firewall rules).

## GENERAL CONTEXT

[Refer to AGENTS.md for project structure description]

ALWAYS use absolute paths.

### REPO

`/Users/tr0n/Code/ritchie`

### RELEVANT FILES

* `/Users/tr0n/Code/ritchie/charts/acestream/values.yaml`
* `/Users/tr0n/Code/ritchie/charts/acestream/templates/deployment.yaml`

## PLAN

Symptom: `/ace/manifest.m3u8` returns a redirect quickly, but the per-stream playlist under `/ace/m/<stream>/<playlist>.m3u8` often times out.

One major cause is poor inbound connectivity: peers cannot connect back to our AceStream engine.

### What we changed in-cluster

We bind AceStream P2P/control ports directly on the node via `hostPort` so inbound connections can reach the pod.

- Values: [`charts/acestream/values.yaml`](charts/acestream/values.yaml:1)
- Deployment: [`charts/acestream/templates/deployment.yaml`](charts/acestream/templates/deployment.yaml:1)

Ports exposed on the node:

- `8621/tcp` and `8621/udp`
- `62062/tcp`

### What you must do outside the cluster (Hetzner firewall)

Open inbound on the Hetzner Cloud firewall attached to `neumann-master1`:

- TCP 8621
- UDP 8621
- TCP 62062

If these ports are blocked at the firewall, `hostPort` alone won’t help.

### Verify

From your laptop:

```bash
# should connect (even if it doesn't speak HTTP)
nc -vz 5.75.129.215 8621
nc -vz 5.75.129.215 62062
```

Then re-test HLS generation:

```bash
curl -k -I 'https://ace.tonioriol.com/ace/manifest.m3u8?id=<INFOHASH>&transcode_audio=1&pid=test'
```

Note: some infohashes are simply dead/slow regardless of connectivity.

## EVENT LOG

## Next Steps

- [ ] Ensure Hetzner firewall allows inbound TCP/UDP 8621 and TCP 62062 to the node.
- [ ] Validate HLS playlist generation for multiple infohashes after firewall changes.

