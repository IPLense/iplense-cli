# Changelog

## 1.0.0

First release.

- Self-check of this machine's public IP over IPv4 and IPv6 (`/cli/v1/self`, schema `cli-self/1`): ASN, operator, location, IPLense score, purity risk value, network type, and each data source's location, types, risk value and risk factors.
- Local checks: ChatGPT and Claude regions against their official lists; Gemini, Netflix, Disney+, YouTube Premium, TikTok, Prime Video and Reddit; outbound port 25.
- Chinese and English output, 80–120 columns, colour only on terminals (`NO_COLOR` honoured), JSON with `-j`, saving with `-o`.
- A request a proxy carries out over the other IP family is reported as such (`X-IPLense-Family`) instead of repeating the other family's result, and is not counted against the limits.
- When the platforms leave through a different exit than the IP checked above (split routing), the local checks name that exit.
- Needs bash 3.2+ and curl; no root, no temporary files.
