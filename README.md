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
| `-l zh\|en` | Output language (default from `LANG`) |
| `-j` | JSON output |
| `-o FILE` | Also save the output to FILE (without colours) |
| `-h` / `-V` | Help / version |

It needs bash and curl. It does not need root, installs nothing, and writes no file except the one named with `-o`.
Colour is used only when the output is a terminal; set `NO_COLOR=1` to turn it off.

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

Example output with documentation addresses (`203.0.113.0/24`):

```text
IPLense self-check  1.0.0

IPv4  203.0.113.45
  AS64500 · Example Cloud Networks · IDC
  Operator  Example Cloud Networks LLC · IDC
  Japan · Tokyo

  Score 72    IP Purity Risk value 18/100    Native · Datacenter

  Source         Location                       Usage     Company   Risk value
  IPLocate       JP · Tokyo                     IDC       Business          35
  ipapi.is       JP · Shinagawa                 IDC       IDC                8
  IPGeolocation  Quota temporarily unavailable
  ...

  Full result  https://iplense.cc/en/ip/203.0.113.45

Local checks · IPv4
  ChatGPT           Supported region  CA
  Claude            Supported region  CA
  Netflix           Available         CA
  ...
  Outbound port 25  Available
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
