# IPLense CLI

[中文说明](README.zh-CN.md)

Check this machine's own public IP from a terminal: ownership, network type, purity risk and multi-source risk from
[IPLense](https://iplense.cc), plus what AI and streaming platforms and a mail server answer this machine.

```bash
bash <(curl -sL https://iplense.cc/cli)
```

To check the script before running it, compare its digest with the published one:

```bash
curl -sL https://iplense.cc/cli -o iplense.sh && curl -sL https://iplense.cc/cli/sha256
```

```bash
sha256sum iplense.sh
```

Then run `bash iplense.sh`. The same file is attached to each release with `SHA256SUMS`.

## Options

| Option | Meaning |
| --- | --- |
| `-4` / `-6` | Check IPv4 or IPv6 only (default: both) |
| `-l zh\|en` | Output language; `cn` is the same as `zh` (default from `LANG`) |
| `-j` | JSON output |
| `-o FILE` | Also save the output to FILE (without colours) |
| `-h` / `-V` | Help / version |

It needs bash and curl. It does not need root, installs nothing, and writes no file except the one named with `-o`.
Colour is used only when the output is a terminal; set `NO_COLOR=1` to turn it off. The file written with `-o` and the
JSON output carry no colour.

## Colours

Each colour is the website's own (in `code/assets` of the IPLense site), shown as the nearest of the 16 basic ANSI colours
by hue so that every common terminal can show it. Types, levels and check results are labels on that background
(white text, black on yellow); numbers and marks are in that colour.

| Shown | Website class (colour) | Terminal |
| --- | --- | --- |
| ISP type, Native, Residential / home broadband, available, supported region | `.type-badge.state-isp`, `.semantic-badge.state-success` (`#08754b`), `.outbound-ai-region.is-supported` (`--green` `#12885a`) | green background (42) |
| IDC type, Datacenter, other natures, failed field, unavailable, not a supported region | `.type-badge.state-idc` (`--red` `#b72f3d`), `.state-error` (`#a82332`), `.outbound-ai-region.is-unsupported` | red background (41) |
| Business type, Broadcast, Professional "Other" type, Netflix originals only | `.type-badge.state-business`, `.semantic-badge.state-warning`, `.pro-type-table .canonical-badge.state-unknown`, `.tool-state.is-warning` (`--amber` `#a15c08`) | yellow background (43) |
| Quick "Unknown" type, check failed | `.semantic-badge.state-unknown` (`#596779`), `.mini-cell.is-failed` (faded) | bright black background (100) |
| IPLense score: 80 and up / 60–79 / below 60 | `.score-ring.score-high` / `medium` / `low` (`query_controller.ts`) | green / yellow / red (32 / 33 / 31), with a 20-cell scale in the same segments |
| Risk value: up to 20 / 21–50 / above 50 (purity and each source) | `.pro-risk-number.is-low` / `medium` / `high` (`query_controller.ts`), `.purity-segment-*` (`QuickPurityCalculator`) | green / yellow / red, the purity value with its scale and level |
| Risk factor: detected / not detected / not provided | `.risk-cell.is-detected` / `.is-clear` / `.is-none` | red / green / bright black (31 / 32 / 90) |
| Quota unavailable / call failed | `.pro-state[data-state="quota"]` / `[data-state="error"]` | yellow / red (33 / 31) |
| Section titles and the header border | `--blue` (`#1769e0`) | bold bright blue (94) |

Hues: green (about 155°) is nearest ANSI green, red (about 355°) ANSI red, amber (about 33°) ANSI yellow, blue (215°) ANSI
blue rather than cyan; the slate grey has almost no hue and is bright black. Blue is the bright one so that it reads on dark
backgrounds.

## What it checks

- **This IP** (from iplense.cc): ASN, operator and location; the IPLense score, purity risk value and network type; and
  each data source's location, usage and company type, risk value and risk factors.
- **Local checks** (from this machine, over IPv4 on a dual-stack machine):
  - ChatGPT and Claude: the region each platform sees, against their official supported-region lists;
  - Gemini, Netflix, Disney+, YouTube Premium, TikTok, Prime Video and Reddit: available or not, and the region;
  - outbound port 25: whether a public mail server (Gmail's MX) answers.

  A check that gets no clear answer says "Check failed"; it never guesses.

## What it sends

- **iplense.cc** receives one request per IP family, with the headers `X-IPLense-CLI: 1` and `X-IPLense-Family` (4 or 6) and the User-Agent
  `IPLense-CLI/<version>`. It looks up only the address the request comes from; nothing about this machine is sent.
- **Data sources**: iplense.cc asks its IP data providers about that address, as a lookup on the website does.
- **Platforms checked**:
  - each receives one to three ordinary requests with a desktop browser User-Agent, and sees this machine's IP;
  - the script does not log in or submit any account details;
  - the Disney+ check registers an anonymous device with a generic description (browser, Chrome, Windows), as the open-source
    scripts credited below do.
- **Port 25**: one connection to Gmail's mail server. The script reads its greeting and says `QUIT`; no mail is sent.
- Local check results stay on this machine; they are not uploaded.

See the [IPLense privacy policy](https://iplense.cc/en/privacy) for how iplense.cc handles the lookups.

## Limits

- The self-check allows 3 lookups per IP per 10 minutes and 10 per day.
- One IP's result is kept for an hour, so running the script again within the hour returns the same result without
  asking the data providers again.
- When a limit is reached, the script says when to try again.

## Example

Example output with documentation addresses (`203.0.113.0/24`), IPv4 only, 80 columns (risk values stand side by side
when they fit on one line):

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│                              IPLense self-check                              │
└──────────────────────────────────────────────────────────────────────────────┘
  203.0.113.45 · CLI 1.1.0 · 2026-10-05 01:00 UTC

1. Basics
  ASN            AS64500 · Example Cloud Networks   IDC
  Operator       Example Cloud Networks LLC   IDC
  Location       Japan · Tokyo
  Registered in  JP
  IP Property     Native   Datacenter

2. Multi-source IP Types
  Source         Location                                Usage       Company
  IPLocate       JP · Tokyo                              IDC         Business
  ipapi.is       JP · Shinagawa                          IDC         IDC
  ipdata         JP · Higashi-Ōsaka                      IDC         Business
  Abstract API   JP · Tokyo                              IDC         –
  IPinfo         JP · Tokyo                              IDC         –
  Proxycheck     JP · Tokyo                              Business    –
  IPGeolocation  Quota temporarily unavailable
  Ipregistry     This call failed

3. Risk scores
  IPLense Score                 72  ━━━━━━━━━━━━━━┃━━━━━
  IP Purity Risk value      18/100  ━━━┃━━━━━━━━━━━━━━━━  Low

  Source      IPLocate  ipapi.is  ipdata  Abstract API  Proxycheck  AbuseIPDB
  Risk value  35        8         62      Medium        0           0

4. Risk factors
  Source         Hosting Proxy   VPN     Tor     Relay   Abuse   Bot
  IPLocate       ●       ·       ·       ·       –       ·       –
  ipapi.is       ●       ·       ·       ·       –       ·       –
  ipdata         ●       ●       –       ·       ·       ●       –
  Abstract API   ●       ·       ·       ·       ·       –       –
  Proxycheck     –       ·       ·       –       –       –       –
  AbuseIPDB      –       –       –       –       –       ·       –
  ● Detected  · Not detected  – Not provided

5. AI and streaming · IPv4
  ChatGPT            Supported region   CA
  Claude             Supported region   CA
  Gemini             Available          CA
  Netflix            Available          CA
  Disney+            Available          CA
  YouTube Premium    Available          CA
  TikTok             Available          CA
  Prime Video        Available          CA
  Reddit             Available          CA

6. Outbound port 25
   Available

────────────────────────────────────────────────────────────────────────────────
  Full result    https://iplense.cc/en/ip/203.0.113.45
  About the CLI  https://iplense.cc/en/cli
```

## Development

- `iplense.sh` runs on bash 3.2 and later.
- Tests use a stub `curl` and fixtures, and never reach the network:

```bash
shellcheck iplense.sh tests/run.sh tests/stub/curl
```

```bash
bash tests/run.sh
```

After an intended output change, `UPDATE=1 bash tests/run.sh` rewrites the snapshots.

## Credits

Several local checks follow the response markers used by
[xykt/IPQuality](https://github.com/xykt/IPQuality) and
[lmc999/RegionRestrictionCheck](https://github.com/lmc999/RegionRestrictionCheck), both AGPL-3.0; each check in the
script names the one it follows.

## License

[GNU Affero General Public License v3.0](LICENSE). Copyright © 2026 IPLense.
