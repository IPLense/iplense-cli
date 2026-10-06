# Changelog

## 1.1.1

Gemini and YouTube Premium checks, and the score's grade word.

- Gemini: Google now serves pages with and without the old experiment flags in every region, so the page alone no longer tells. The check asks NotebookLM over the same IP family without following its redirect: `location=unsupported` is unavailable, a redirect to notebook.google.com is available. A region Google restricts (AFG, CHN, RUS, BLR, CUB, IRN, PRK, SYR) stated on the page is unavailable before anything else, a Google sorry page is a failed check, HTTP 403 or 451 is unavailable, and the old flags remain a fallback. The region is shown when the page states exactly one.
- YouTube Premium: available only when the page carries the purchase button or offer cards (`premiumPurchaseButtonRenderer`, `lpOfferCardViewModel`), with the region shown when the page states exactly one; the not-available notice (country or region) and a redirect to google.cn are unavailable; a consent or sign-in page is a failed check. The page is requested with `?hl=en`.
- The IPLense score carries its grade word (Excellent, Good, Low), as on the result page, so a higher score does not read like a higher risk value. The self-check sends these three words; every key earlier clients read is unchanged.

## 1.1.0

Output redesign.

- A report with a bordered header (the IPs, the version and when the result was made) and numbered sections: basics, multi-source IP types, risk scores, risk factors, AI and streaming, outbound port 25; links to the full result and the CLI page at the end.
- Types, levels and check results are coloured labels, and the IPLense score and purity risk value have a 20-cell scale, all in the website's colours mapped to the 16 basic ANSI colours (README "Colours").
- Each source's risk value stands side by side with the others when they fit on one line.
- `-l cn` is the same as `-l zh`.
- The self-check sends five more words (section titles, registration region, IP property); every key 1.0.0 reads is unchanged, so 1.0.0 keeps working.

## 1.0.0

First release.

- Self-check of this machine's public IP over IPv4 and IPv6 (`/cli/v1/self`, schema `cli-self/1`): ASN, operator, location, IPLense score, purity risk value, network type, and each data source's location, types, risk value and risk factors.
- Local checks: ChatGPT and Claude regions against their official lists; Gemini, Netflix, Disney+, YouTube Premium, TikTok, Prime Video and Reddit; outbound port 25.
- Chinese and English output, 80–120 columns, colour only on terminals (`NO_COLOR` honoured), JSON with `-j`, saving with `-o`.
- A request a proxy carries out over the other IP family is reported as such (`X-IPLense-Family`) instead of repeating the other family's result, and is not counted against the limits.
- When the platforms leave through a different exit than the IP checked above (split routing), the local checks name that exit.
- Needs bash 3.2+ and curl; no root, no temporary files.
