# DNS Records Backup — Pre-Migration Snapshot
# Generated: 2026-03-13
# Purpose: Complete record of all DNS before migrating to Cloudflare

## tonioriol.com (DO DNS → already on CF DNS)
## NOTE: DO still has old records, CF is authoritative
| Type  | Name       | Value                                          | Priority | TTL  |
|-------|------------|------------------------------------------------|----------|------|
| A     | @          | 188.166.129.145                                | -        | 1800 |
| CNAME | www        | ghs.google.com                                 | -        | 1800 |
| TXT   | @          | keybase-site-verification=uM15MdybJLLE73nnGH8sUyopzpU5Fm5RXkmjDVtL7no | - | 1800 |
| MX    | @          | aspmx.l.google.com                             | 1        | 1800 |
| MX    | @          | alt1.aspmx.l.google.com                        | 5        | 1800 |
| MX    | @          | alt2.aspmx.l.google.com                        | 5        | 1800 |
| MX    | @          | alt3.aspmx.l.google.com                        | 10       | 1800 |
| MX    | @          | alt4.aspmx.l.google.com                        | 10       | 1800 |
| CNAME | piticli    | piticli.tonioriol.com.herokudns.com            | -        | 60   |
| A     | pi         | 79.116.23.149                                  | -        | 30   |
| A     | ace        | 5.75.129.215                                   | -        | 30   |
| A     | neumann    | 5.75.129.215                                   | -        | 30   |
| A     | *.neumann  | 5.75.129.215                                   | -        | 30   |

## bertomeuiglesias.com (DO DNS)
| Type  | Name | Value                       | Priority | TTL  |
|-------|------|-----------------------------|----------|------|
| A     | @    | 188.226.140.165             | -        | 30   |
| MX    | @    | aspmx.l.google.com          | 1        | 1800 |
| MX    | @    | alt1.aspmx.l.google.com     | 5        | 1800 |
| MX    | @    | alt2.aspmx.l.google.com     | 5        | 1800 |
| MX    | @    | alt3.aspmx.l.google.com     | 10       | 1800 |
| MX    | @    | alt4.aspmx.l.google.com     | 10       | 1800 |
| CNAME | www  | @                           | -        | 1800 |

## boira.band (DO DNS)
| Type  | Name | Value                       | Priority | TTL  |
|-------|------|-----------------------------|----------|------|
| A     | @    | 188.226.140.165             | -        | 30   |
| MX    | @    | aspmx.l.google.com          | 1        | 1800 |
| MX    | @    | alt1.aspmx.l.google.com     | 5        | 1800 |
| MX    | @    | alt2.aspmx.l.google.com     | 5        | 1800 |
| MX    | @    | alt3.aspmx.l.google.com     | 10       | 1800 |
| MX    | @    | alt4.aspmx.l.google.com     | 10       | 1800 |
| CNAME | www  | @                           | -        | 1800 |

## juanjoseoriol.com (DO DNS)
| Type  | Name | Value                       | Priority | TTL  |
|-------|------|-----------------------------|----------|------|
| MX    | @    | aspmx.l.google.com          | 1        | 1800 |
| MX    | @    | alt1.aspmx.l.google.com     | 5        | 1800 |
| MX    | @    | alt2.aspmx.l.google.com     | 5        | 1800 |
| MX    | @    | alt3.aspmx.l.google.com     | 10       | 1800 |
| MX    | @    | alt4.aspmx.l.google.com     | 10       | 1800 |

## lodrago.net (DO DNS)
| Type  | Name | Value                       | Priority | TTL  |
|-------|------|-----------------------------|----------|------|
| A     | @    | 188.226.140.165             | -        | 30   |
| MX    | @    | aspmx.l.google.com          | 1        | 1800 |
| MX    | @    | alt1.aspmx.l.google.com     | 5        | 1800 |
| MX    | @    | alt2.aspmx.l.google.com     | 5        | 1800 |
| MX    | @    | alt3.aspmx.l.google.com     | 10       | 1800 |
| MX    | @    | alt4.aspmx.l.google.com     | 10       | 1800 |
| CNAME | www  | @                           | -        | 1800 |
| TXT   | @    | google-site-verification=3HH9-ZDQWUW25YLVWGBsHD3BDoxQfsnjPaNjqWPv3VM | - | 3600 |

## neutronica.net (DO DNS)
| Type  | Name | Value                       | Priority | TTL  |
|-------|------|-----------------------------|----------|------|
| MX    | @    | aspmx.l.google.com          | 1        | 1800 |
| MX    | @    | alt1.aspmx.l.google.com     | 5        | 1800 |
| MX    | @    | alt2.aspmx.l.google.com     | 5        | 1800 |
| MX    | @    | alt3.aspmx.l.google.com     | 10       | 1800 |
| MX    | @    | alt4.aspmx.l.google.com     | 10       | 1800 |
| A     | @    | 216.239.32.21               | -        | 50   |
| A     | www  | 216.239.32.21               | -        | 1800 |

## ultra.coffee (DO DNS)
| Type  | Name | Value                       | Priority | TTL  |
|-------|------|-----------------------------|----------|------|
| TXT   | @    | google-site-verification=rpg0L4MV-ee7OnwW-iaAKktxe1O-y3O1PcI-YtfHsfg | - | 30 |
| MX    | @    | smtp.google.com             | 1        | 30   |

## adamnfinecupof.coffee (Namecheap DNS)
| Type  | Name | Value                              | Priority | TTL  |
|-------|------|------------------------------------|----------|------|
| CNAME | www  | parkingpage.namecheap.com          | -        | 1800 |
| URL   | @    | http://www.adamnfinecupof.coffee/  | -        | 1800 |
NOTE: URL redirect (not a DNS record) — will need CF Page Rule or Redirect Rule

## orioliglesias.com (Namecheap DNS)
| Type  | Name | Value                              | Priority | TTL  |
|-------|------|------------------------------------|----------|------|
| CNAME | www  | parkingpage.namecheap.com          | -        | 1800 |
| URL   | @    | http://www.orioliglesias.com/      | -        | 1800 |
| MX    | @    | eforward1.registrar-servers.com    | 10       | 1800 |
| MX    | @    | eforward2.registrar-servers.com    | 10       | 1800 |
| MX    | @    | eforward3.registrar-servers.com    | 10       | 1800 |
| MX    | @    | eforward4.registrar-servers.com    | 15       | 1800 |
| MX    | @    | eforward5.registrar-servers.com    | 20       | 1800 |
| TXT   | @    | v=spf1 include:spf.efwd.registrar-servers.com ~all | - | 1800 |
NOTE: Uses Namecheap email forwarding — will STOP working after migration!
      Need to set up CF Email Routing or alternative email forwarding.

## gosverd.com (No DNS — broken/no NS responding)
| Type  | Name | Value | Priority | TTL  |
|-------|------|-------|----------|------|
| (none) | - | - | - | - |
NOTE: Domain has no working DNS. Safe to migrate as-is.
