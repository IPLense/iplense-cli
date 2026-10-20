#!/usr/bin/env bash
#
# IPLense CLI: checks this machine's own public IP with IPLense (https://iplense.cc).
# Run: bash <(curl -sL https://iplense.cc/cli)
#
# Copyright (C) 2026 IPLense
#
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General
# Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along with this program. If not, see
# <https://www.gnu.org/licenses/>.
#
# What it sends: one request per IP family to iplense.cc with the header "X-IPLense-CLI: 1" and the User-Agent
# "IPLense-CLI/<version>"; the server sees only the connection IP. The local checks send one to three ordinary requests
# to each platform checked (Disney+ registers an anonymous device with a generic description) and open port 25 to one
# public mail server; those see the connection IP. Report creation sends tokens, version, language, local statuses and
# regions, port 25 status and a masked differing exit. Reports last 30 days; -p and -j skip creation.
# It needs bash and curl, no root, installs nothing, and writes no file except the one named with -o.

VERSION=1.3.2
BASE=https://iplense.cc
SCHEMA=cli-self/1

LANG_UI=en
FAMILIES='4 6'
JSON=0
OUT=
FULL=0
PRIVATE=0

# ---------------------------------------------------------------------------------------------------------------------
# Text

t() {
	local zh en
	case $1 in
	title) zh='命令行 IP 体检'; en='CLI IP check' ;;
	section_score) zh='IP 评分'; en='IP score' ;;
	section_basics) zh='基础信息'; en='Basics' ;;
	section_types) zh='多源 IP 类型'; en='IP types by source' ;;
	asn_name) zh='ASN 名称'; en='ASN name' ;;
	as_number) zh='AS 号码'; en='AS number' ;;
	registered_in) zh='IP 注册地区'; en='Registered in' ;;
	used_in) zh='IP 使用地区'; en='Used in' ;;
	human) zh='人类'; en='Human' ;;
	automated) zh='自动化'; en='Bots' ;;
	risk_low) zh='低风险'; en='Low risk' ;;
	risk_medium) zh='中风险'; en='Medium' ;;
	risk_high) zh='高风险'; en='High risk' ;;
	unlocked) zh='解锁'; en='Unlocked' ;;
	blocked) zh='屏蔽'; en='Blocked' ;;
	port_open) zh='可用'; en='Open' ;;
	mail_progress) zh='正在检测各邮件服务商的 25 端口…'; en='Checking port 25 at each mail provider…' ;;
	checking) zh='正在查询本机 IPv%s 结果…'; en="Querying this machine's IPv%s result…" ;;
	no_conn) zh='无连接'; en='No connection' ;;
	other_family) zh='无 IPv%s 出口：请求以 IPv%s 到达（%s）'; en='No IPv%s exit: the request arrived over IPv%s (%s)' ;;
	other_family_shown) zh='无 IPv%s 出口：请求以 IPv%s 到达'; en='No IPv%s exit: the request arrived over IPv%s' ;;
	all_failed) zh='无法连接 iplense.cc'; en='Cannot reach iplense.cc' ;;
	cli_disabled) zh='自检接口暂时停用'; en='The self-check is switched off' ;;
	header_required) zh='请求缺少客户端标识，请使用最新脚本'; en='Request not recognised; use the latest script' ;;
	not_public) zh='连接地址不是公网 IP'; en='The connection IP is not public' ;;
	quick_unavailable) zh='查询暂时不可用，请稍后再试'; en='Lookup temporarily unavailable; try again later' ;;
	limit_ip) zh='本 IP 检测次数已达上限，%s后再试'; en='Check limit reached for this IP; try again in %s' ;;
	limit_site) zh='今日检测次数已达上限，%s后再试'; en='Daily check limit reached; try again in %s' ;;
	server_error) zh='服务器返回 HTTP %s'; en='Server answered HTTP %s' ;;
	schema) zh='响应格式不兼容，请获取最新脚本'; en='Response format not supported; get the latest script' ;;
	minutes) zh='%s 分钟'; en='%s min' ;;
	hours) zh='%s 小时'; en='%s h' ;;
	report) zh='报告链接'; en='Report link' ;;
	retention) zh='（保留 30 天）'; en='(30 days)' ;;
	report_missing) zh='未取得报告令牌，请重新自检'; en='No report token; run the self-check again' ;;
	report_mismatch) zh='报告出口不匹配，请从成功检测的出口重新自检'; en='Report exit mismatch; repeat the self-check from a checked exit' ;;
	report_invalid) zh='报告请求字段无效：%s'; en='Invalid report field: %s' ;;
	section_risk) zh='多源 IP 风险'; en='IP risk by source' ;;
	status) zh='状态'; en='Status' ;;
	region_label) zh='地区'; en='Region' ;;
	client_name) zh='命令行'; en='CLI' ;;
	cli_page) zh='关于命令行'; en='About the CLI' ;;
	platforms) zh='AI 与流媒体'; en='AI and streaming' ;;
	local_progress) zh='正在检测 %s（%s/%s）…'; en='Checking %s (%s/%s)…' ;;
	local_exit) zh='出口 %s'; en='exit %s' ;;
	local_exit_note) zh='与上方检测的 IP 不同，平台看到的是这个出口'; en='Differs from the IP checked above; the platforms see this exit' ;;
	available) zh='可用'; en='Available' ;;
	unavailable) zh='不可用'; en='Unavailable' ;;
	failed) zh='失败'; en='Failed' ;;
	originals_only) zh='仅自制'; en='Originals' ;;
	port25) zh='出站 25 端口'; en='Outbound port 25' ;;
	saved) zh='已保存到 %s'; en='Saved to %s' ;;
	write_failed) zh='无法写入 %s'; en='Cannot write %s' ;;
	need_curl) zh='需要 curl'; en='curl is required' ;;
	bad_option) zh='未知参数，使用 -h 查看用法'; en='Unknown option; see -h' ;;
	*) zh=$1; en=$1 ;;
	esac
	if [ "$LANG_UI" = zh ]; then printf '%s' "$zh"; else printf '%s' "$en"; fi
}

# A message with its values filled in; the formats are this script's own text.
tf() {
	local format
	format=$(t "$1")
	shift
	# shellcheck disable=SC2059
	printf "$format" "$@"
}

usage() {
	if [ "$LANG_UI" = zh ]; then
		printf '%s\n' \
			'IPLense 命令行自检：检测本机出口 IP 的归属、类型与多源风险，以及 AI 平台、流媒体与 25 端口。' \
			'' \
			'用法：bash <(curl -sL https://iplense.cc/cli) [选项]' \
			'  -4         只检测 IPv4' \
			'  -6         只检测 IPv6' \
			'  -l zh|en   输出语言（cn 同 zh；默认按 LANG）' \
			'  -j         输出 JSON' \
			'  -f         显示完整 IP、网段（含名称）与反向解析' \
			'  -p         不生成报告，不上传本地检测结果' \
			'  -o 文件    同时把输出保存到文件' \
			'  -h         显示本帮助' \
			'  -V         显示版本' \
			'' \
			'向 iplense.cc 每个协议族发一次请求，服务器只得到连接 IP。' \
			'本地检测每个协议族向各平台发 1–3 次请求；Disney+ 会注册匿名设备。' \
			'25 端口可用时，经 Cloudflare DNS-over-HTTPS 查询 12 家邮件服务商的邮件服务器并逐个连接 25 端口。' \
			'默认生成报告：上传自检令牌、版本、语言、11 个平台的状态与地区、25 端口与邮件服务商结果，' \
			'以及出口是否不同和脱敏出口 IP；只保存脱敏报告，保留 30 天，持有链接者可查看。' \
			'-p 或 -j 不生成报告；-f 通过系统 DNS 查询检测 IP 的反向解析。' \
			'不需要 root，不安装任何软件，除 -o 指定的文件外不写文件。'
	else
		printf '%s\n' \
			'IPLense self-check: ownership, type and multi-source risk of this machine'"'"'s public IP, plus AI, streaming and port 25.' \
			'' \
			'Usage: bash <(curl -sL https://iplense.cc/cli) [options]' \
			'  -4         IPv4 only' \
			'  -6         IPv6 only' \
			'  -l zh|en   Output language (cn = zh; default from LANG)' \
			'  -j         JSON output' \
			'  -f         Full IP, network range (with name) and reverse DNS' \
			'  -p         Skip report creation and local-result upload' \
			'  -o FILE    Also save the output to FILE' \
			'  -h         Show this help' \
			'  -V         Show the version' \
			'' \
			'Sends one request per IP family to iplense.cc; the server sees only the connection IP.' \
			'Local checks send 1-3 requests per family to each platform; Disney+ registers an anonymous device.' \
			'Where port 25 is open, twelve mail providers are looked up over Cloudflare DNS-over-HTTPS and tried on port 25.' \
			'Reports upload self-check tokens, version, language, 11 platform statuses and regions, port 25 and mail results,' \
			'and whether the exit differs and its masked IP. Only masked reports are stored, for 30 days.' \
			"Anyone with the link can view it. -p or -j skips reports; -f queries system DNS for the checked IP's PTR." \
			'Needs no root, installs nothing, and writes no file except the one named with -o.'
	fi
}

# ---------------------------------------------------------------------------------------------------------------------
# Terminal text: control characters out, display widths for CJK, colour only when it can be shown

# Removes every C0 control except the line break, DEL, and the two-byte C1 controls (U+0080-U+009F).
strip_controls() {
	local LC_ALL=C s=$1
	s=${s//[$'\001'-$'\011'$'\013'-$'\037'$'\177']/}
	s=${s//$'\302'[$'\200'-$'\237']/}
	printf '%s' "$s"
}

# Display width in columns: one per character, two for CJK, Hangul and other four-byte characters.
width() {
	local LC_ALL=C s=$1 chars wide
	chars=${s//[$'\200'-$'\277']/}
	wide=${chars//[^$'\343'-$'\355'$'\360'-$'\364']/}
	printf '%s' $((${#chars} + ${#wide}))
}

# Complete text split into lines of at most $2 display columns. No ellipsis or discarded text.
wrap_text() {
	local LC_ALL=C rest=$1 out='' ch max=$2
	while [ -n "$rest" ]; do
		ch=${rest:0:1}; rest=${rest:1}
		while [ -n "$rest" ]; do
			case ${rest:0:1} in [$'\200'-$'\277']) ch=$ch${rest:0:1}; rest=${rest:1} ;; *) break ;; esac
		done
		if [ "$(width "$out$ch")" -gt "$max" ]; then
			case $out in
			*' '*) printf '%s\n' "${out% *}"; out=${out##* } ;;
			*) printf '%s\n' "$out"; out='' ;;
			esac
		fi
		out=$out$ch
	done
	printf '%s' "$out"
}

# Mask at the output boundary; compressed IPv6 is expanded before selecting its first three groups.
mask_ip() {
	local ip=$1 left right missing parts=() groups=() part
	case $ip in
	*.*.*.*)
		case $ip in *:*) ;; *) printf '%s.*.*' "${ip%.*.*}"; return ;; esac
		;;
	esac
	case $ip in *:*) ;; *) printf '%s' "$ip"; return ;; esac
	# An embedded IPv4 tail occupies two IPv6 groups, beyond the /48 kept here.
	case $ip in *.*) ip=${ip%:*}:0:0 ;; esac
	if [[ $ip == *::* ]]; then
		left=${ip%%::*}; right=${ip#*::}
		IFS=: read -r -a parts <<<"$left"
		groups=("${parts[@]}")
		IFS=: read -r -a parts <<<"$right"
		missing=$((8 - ${#groups[@]} - ${#parts[@]}))
		while [ "$missing" -gt 0 ]; do groups[${#groups[@]}]=0; missing=$((missing - 1)); done
		groups=("${groups[@]}" "${parts[@]}")
	else
		IFS=: read -r -a groups <<<"$ip"
	fi
	if [ "${#groups[@]}" != 8 ]; then printf '%s' "$1"; return; fi
	for part in "${groups[@]:0:3}"; do
		# Keep a canonical zero rather than dropping an entire group.
		while [ "${#part}" -gt 1 ] && [ "${part:0:1}" = 0 ]; do part=${part:1}; done
		printf '%s:' "$part"
	done
	printf '*:*:*:*:*'
}

display_ip() {
	if [ "$FULL" = 1 ]; then printf '%s' "$1"; else mask_ip "$1"; fi
}

# Preserve the JSON response shape, masking addresses wherever repeated in nested public results.
# Route/name/PTR strings are shown only with -f, as in the text report.
private_json() {
	local data=$1 ip ips
	data=$(printf '%s' "$data" | sed -E 's/,[[:space:]]*"reportToken"[[:space:]]*:[[:space:]]*"[^"]*"//g')
	if [ "$FULL" = 1 ]; then printf '%s' "$data"; return; fi
	data=$(printf '%s' "$data" | sed -E 's/("(route|netname|reverseDns)"[[:space:]]*:[[:space:]]*)"([^"\\]|\\.)*"/\1null/g')
	ips=$(printf '%s' "$data" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}|([0-9A-Fa-f]{0,4}:){2,7}[0-9A-Fa-f]{0,4}' | sort -u)
	while IFS= read -r ip; do
		[ -z "$ip" ] && continue
		data=${data//"$ip"/$(mask_ip "$ip")}
	done <<<"$ips"
	printf '%s' "$data"
}

percent() { awk -v v="$1" 'BEGIN { if (v < 0) v = 0; if (v > 100) v = 100; s = sprintf("%.2f", v); sub(/0+$/, "", s); sub(/\.$/, "", s); print s }'; }

# Simple fields may wrap, while their label appears only on the first line.
detail() {
	local name=$1 text=$2 lw=$3 row first=1
	while IFS= read -r row; do
		if [ "$first" = 1 ]; then printf '  %s' "$(cell "$name" "$lw" dim)"; else printf '  %*s' "$lw" ''; fi
		printf '%s\n' "$row"; first=0
	done <<<"$(wrap_text "$text" $((COLS - lw - 2)))"
}

# One cell: text padded to $2 columns (right-aligned when $4 is "r"), coloured with style $3. A left-aligned cell keeps at
# its requested blank columns before the next one. Callers wrap long content before placing it in cells.
cell() {
	local text w pad
	text=$1
	w=$(width "$text")
	pad=$(($2 - w))
	[ "$pad" -lt 0 ] && pad=0
	if [ "${4-}" = r ]; then printf '%*s' "$pad" ''; fi
	paint "$3" "$text"
	if [ "${4-}" != r ]; then printf '%*s' "$pad" ''; fi
}

# Colours, each the nearest of the 16 basic ANSI colours to the website's own (README "Colours"): pos green, neu yellow,
# neg red, info blue (education and government), none bright black (unknown, failed, not provided); a style starting with b
# is a label on that background.
paint() {
	if [ "$COLOR" = 1 ] && [ -n "$1" ] && [ -n "$2" ]; then
		local code
		case $1 in
		pos) code=32 ;; neu) code=33 ;; neg) code=31 ;; none) code=90 ;; dim) code=2 ;; bold) code=1 ;; head) code='1;94' ;;
		bpos) code='97;42' ;; bneu) code='30;43' ;; bneg) code='97;41' ;; binfo) code='97;44' ;; bnone) code='97;100' ;; *) code=0 ;;
		esac
		printf '\033[%sm%s\033[0m' "$code" "$2"
	else
		printf '%s' "$2"
	fi
}

# A label: the text with a space either side, on the style's background, padded to $2 columns. Without colour the spaces
# stay, so a label column lines up the same way.
label() {
	local text=" $1 " pad
	pad=$(($2 - $(width "$text")))
	[ "$pad" -lt 0 ] && pad=0
	paint "$3" "$text"
	printf '%*s' "$pad" ''
}

# A cell whose style says whether it is a label (b...) or text.
any_cell() {
	case $3 in b*) label "$1" "$2" "$3" ;; *) cell "$@" ;; esac
}

# $1 repeated $2 times.
repeat() {
	local s
	printf -v s '%*s' "$2" ''
	printf '%s' "${s// /$1}"
}

# ---------------------------------------------------------------------------------------------------------------------
# Server data: kv lines kept as K4_* / K6_* variables (names checked before use; nothing is evaluated)

parse_kv() {
	local family=$1 line key IFS=$'\n'
	set -f
	for line in $2; do
		case $line in *=*) ;; *) continue ;; esac
		key=${line%%=*}
		case $key in '' | *[!A-Za-z0-9_.]*) continue ;; esac
		printf -v "K${family}_${key//./__}" '%s' "${line#*=}"
	done
	set +f
}

v() {
	local name="K${F}_${1//./__}"
	printf '%s' "${!name-}"
}

brand() {
	local i=0 p
	while :; do
		p=$(v "brands.$i.provider")
		[ -z "$p" ] && break
		if [ "$p" = "$1" ]; then v "brands.$i.brand"; return; fi
		i=$((i + 1))
	done
	printf '%s' "$1"
}

# Providers in the order they first appear across the location, type and risk lists.
providers() {
	local list=$'\n' section i p
	for section in locations types riskSources; do
		i=0
		while :; do
			p=$(v "professional.$section.$i.provider")
			[ -z "$p" ] && break
			case $list in *$'\n'"$p"$'\n'*) ;; *) list=$list$p$'\n' ;; esac
			i=$((i + 1))
		done
	done
	printf '%s' "${list#$'\n'}"
}

# Index of a provider in a professional list, or nothing.
index_of() {
	local i=0 p
	while :; do
		p=$(v "professional.$1.$i.provider")
		[ -z "$p" ] && return
		if [ "$p" = "$2" ]; then printf '%s' "$i"; return; fi
		i=$((i + 1))
	done
}

# ---------------------------------------------------------------------------------------------------------------------
# Network

# Fetches the self-check over one family; sets BODY, STATUS (HTTP code, or empty when nothing answered).
fetch() {
	local out
	out=$(curl "-$1" -sS --connect-timeout 8 --max-time 40 -H 'X-IPLense-CLI: 1' -H "X-IPLense-Family: $1" -A "IPLense-CLI/$VERSION" \
		-w '\n%{http_code}' "$BASE/cli/v1/self?format=$2&lang=$LANG_UI" 2>/dev/null)
	local rc=$?
	STATUS=${out##*$'\n'}
	BODY=$(strip_controls "${out%$'\n'*}")
	if [ "$rc" -ne 0 ] || [ "$STATUS" = 000 ] || [ -z "$STATUS" ]; then STATUS=; BODY=; fi
}

# ---------------------------------------------------------------------------------------------------------------------
# Layout

later() {
	local s=$1
	if [ "$s" -ge 3600 ]; then
		tf hours $(((s + 3599) / 3600))
	else
		tf minutes $(((s + 59) / 60))
	fi
}

# The reason a family has no result, from the server's error code.
failure() {
	local error scope
	error=$(v error)
	case $error in
	rate_limited)
		scope=$(v scope)
		tf "limit_$scope" "$(later "$(v retryAfter)")"
		;;
	cli_disabled | header_required | not_public | quick_unavailable) t "$error" ;;
	*) tf server_error "$1" ;;
	esac
}

# A Professional type's label colour, as the website's multi-source type table shows it: ISP green, IDC and failure red,
# Business and Unknown (shown as "Other") amber.
type_style() {
	case $1 in ISP) printf bpos ;; IDC | Error) printf bneg ;; Education | Government) printf binfo ;; *) printf bneu ;; esac
}

# A Quick type (ASN and operator) as the web result card colours it, where Unknown is grey.
quick_type_style() {
	case $1 in ISP) printf bpos ;; IDC | Error) printf bneg ;; Business) printf bneu ;; Education | Government) printf binfo ;; *) printf bnone ;; esac
}

# A Quick type as the site's badge (quickType_ words, sent since 1.2.1); an older server's raw value otherwise.
quick_type_text() {
	local text
	text=$(l "quickType_$1")
	printf '%s' "${text:-$1}"
}

# A Professional type in the site's words.
type_text() {
	local text
	[ -z "$1" ] && return 0
	# The server sends a word for each type it can return, so a type added later shows without a new client.
	text=$(l "proType_$1")
	printf '%s' "${text:-$(l proType_Unknown)}"
}

# One of the site's words, sent with a result in the requested language: from the family being shown, else from whichever
# family returned a result (a family a proxy carried over the other one returns no words).
l() {
	local name
	for name in "K${F}_labels__$1" "K4_labels__$1" "K6_labels__$1"; do
		if [ -n "${!name-}" ]; then
			printf '%s' "${!name}"
			return
		fi
	done
}

# Risk values as the website colours them (the purity track and the multi-source risk numbers): up to 20, up to 50, above.
risk_tone() {
	if [ "$1" -le 20 ]; then printf pos; elif [ "$1" -le 50 ]; then printf neu; else printf neg; fi
}

# Scores as the website's score ring: 80 and up, 60 and up, below.
score_tone() {
	if [ "$1" -ge 80 ]; then printf pos; elif [ "$1" -ge 60 ]; then printf neu; else printf neg; fi
}

# Joins the non-empty arguments with " · ", skipping a part equal to the one before it (a city named like its region).
joined() {
	local out='' part last=''
	for part in "$@"; do
		[ -z "$part" ] && continue
		[ "$part" = "$last" ] && continue
		out=${out:+$out$SEP}$part
		last=$part
	done
	printf '%s' "$out"
}

# The larger of two numbers.
max() {
	if [ "$1" -ge "$2" ]; then printf '%s' "$1"; else printf '%s' "$2"; fi
}

# A 0-100 scale of 20 cells in the website's segment colours, with the value's cell marked: risk values green up to 20,
# amber up to 50 and red above (the purity track); scores red below 60, amber below 80 and green from 80 (the score ring).
scale() {
	local v=$1 i=1 at tone run='' last='' out=''
	if [ "$2" = score ]; then at=$((v / 5 + 1)); else at=$(((v + 4) / 5)); fi
	[ "$at" -lt 1 ] && at=1
	[ "$at" -gt 20 ] && at=20
	while [ "$i" -le 20 ]; do
		if [ "$2" = score ]; then
			if [ "$i" -ge 17 ]; then tone=pos; elif [ "$i" -ge 13 ]; then tone=neu; else tone=neg; fi
		elif [ "$i" -le 4 ]; then tone=pos
		elif [ "$i" -le 10 ]; then tone=neu
		else tone=neg; fi
		if [ "$i" = "$at" ]; then
			out=$out$(paint "$last" "$run")$(paint bold "$BAR_AT")
			run=''
		else
			if [ "$tone" != "$last" ] && [ -n "$run" ]; then
				out=$out$(paint "$last" "$run")
				run=''
			fi
			run=$run$BAR
		fi
		last=$tone
		i=$((i + 1))
	done
	printf '%s%s' "$out" "$(paint "$last" "$run")"
}

# The report header: the title and how to run it, then the IPs checked with the version and when the result was made.
render_header() {
	local ips='' family made='' meta left
	for family in $RESULTS; do
		F=$family
		ips="$ips    $(paint head "IPv$family") $(display_ip "$(v ip)")"
		[ -z "$made" ] && made=$(v generatedAt)
	done
	case $made in
	[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]*) made="${made:0:10} ${made:11:5} UTC" ;;
	*) made='' ;;
	esac
	meta="$VERSION${made:+   $made}"
	printf ' %s   %s\n' "$(paint bold "IPLense $(t title)")" "$(paint dim "bash <(curl -sL $BASE/cli)")"
	left=" ${ips#    }"
	[ -z "$ips" ] && left=''
	if [ $(($(vwidth "$left") + $(width "$meta") + 2)) -le "$COLS" ]; then
		printf '%s%*s%s\n' "$left" $((COLS - $(vwidth "$left") - $(width "$meta"))) '' "$(paint dim "$meta")"
	else
		# Complete addresses (-f) may not share a line with the version: each family on its own line, then the version.
		for family in $RESULTS; do F=$family; printf ' %s %s\n' "$(paint head "IPv$family")" "$(display_ip "$(v ip)")"; done
		printf ' %s\n' "$(paint dim "$meta")"
	fi
	printf '%s\n' "$(paint dim "$(repeat "$BOX_H" "$COLS")")"
}

# A family that has no result: its reason on one line.
render_failure() {
	local family=$1 style text
	text=FAIL_$family
	style=FAIL_STYLE_$family
	printf '  %s  %s\n' "$(paint head "IPv$family")" "$(paint "${!style}" "${!text}")"
}

# ---------------------------------------------------------------------------------------------------------------------
# Rows and columns. A section prints rows "key<US>label<US>cell" for each family; a cell's continuation lines are joined
# with NL. Two families on a terminal of 120 columns stand side by side (IPv4 left), rows with the same key on one line;
# otherwise the families follow one another. The label column is LW wide.

US=$'\037'
NL=$'\036'
LW=16

# Visible width of a coloured string.
vwidth() {
	local LC_ALL=C s=$1
	s=${s//$'\033'\[[0-9]m/}
	s=$(printf '%s' "$s" | sed $'s/\033\\[[0-9;]*m//g')
	width "$s"
}

# A coloured string padded to $2 visible columns, or centred in them when $3 is "c" (an odd remainder goes right, so items of
# the same parity share a centre).
vpad() {
	local pad left
	pad=$(($2 - $(vwidth "$1")))
	[ "$pad" -lt 0 ] && pad=0
	if [ "${3-}" = c ]; then
		left=$((pad / 2))
		printf '%*s%s%*s' "$left" '' "$1" $((pad - left)) ''
	else
		printf '%s%*s' "$1" "$pad" ''
	fi
}

# A label (text on the style's background) one space wider inside when needed, so its width has the parity of $3 and it
# centres exactly under a heading $3 wide.
plabel() {
	local text=" $1 "
	[ $((($(width "$text") - $3) % 2)) != 0 ] && text="$text "
	paint "$2" "$text"
}

# Complete text in lines of at most $2 columns, joined with NL for a cell.
wrap_cell() {
	local out
	out=$(wrap_text "$1" "$2")
	printf '%s' "${out//$'\n'/$NL}"
}

# Non-empty parts joined with ", " (a location as the result page writes it), skipping a part equal to the one before it.
joined_comma() {
	local out='' part last=''
	for part in "$@"; do
		[ -z "$part" ] && continue
		[ "$part" = "$last" ] && continue
		out=${out:+$out, }$part
		last=$part
	done
	printf '%s' "$out"
}

row() { printf '%s%s%s%s%s\n' "$1" "$US" "$2" "$US" "$3"; }

# The value-column width for the current layout.
value_width() {
	local n=0 f
	for f in $FAMS; do n=$((n + 1)); done
	if [ "$WIDE" = 1 ]; then printf '%s' $(((COLS - LW) / n)); else printf '%s' $((COLS - LW)); fi
}

# Prints one section from the row function $1, called once per family in FAMS with F and CW set.
emit() {
	local fn=$1 f keys=$'\n' line key label cell n=0 i j max part
	CW=$(value_width)
	for f in $FAMS; do
		F=$f
		printf -v "ROWS_$f" '%s' "$("$fn" "$f")"
		local ref=ROWS_$f
		while IFS= read -r line; do
			[ -z "$line" ] && continue
			key=${line%%"$US"*}
			case $keys in *$'\n'"$key"$'\n'*) ;; *) keys=$keys$key$'\n' ;; esac
		done <<<"${!ref}"
		n=$((n + 1))
	done
	if [ "$WIDE" = 1 ]; then
		# One key a line: a source's key may contain spaces ("Abstract API").
		while IFS= read -r key <&3; do
			[ -z "$key" ] && continue
			label='' i=0
			local -a left=() right=()
			for f in $FAMS; do
				local ref=ROWS_$f cells=()
				while IFS= read -r line; do
					[ "${line%%"$US"*}" = "$key" ] || continue
					line=${line#*"$US"}
					[ -z "$label" ] && label=${line%%"$US"*}
					cell=${line#*"$US"}
					while IFS= read -r part; do cells[${#cells[@]}]=$part; done <<<"${cell//$NL/$'\n'}"
				done <<<"${!ref}"
				if [ "$i" = 0 ]; then left=("${cells[@]}"); else right=("${cells[@]}"); fi
				i=$((i + 1))
			done
			max=${#left[@]}; [ "${#right[@]}" -gt "$max" ] && max=${#right[@]}
			j=0
			while [ "$j" -lt "$max" ]; do
				if [ "$j" = 0 ]; then printf '%s' "$(vpad "  $label" "$LW")"; else printf '%*s' "$LW" ''; fi
				printf '%s%s\n' "$(vpad "${left[$j]-}" "$CW")" "${right[$j]-}"
				j=$((j + 1))
			done
		done 3<<<"$keys"
		return
	fi
	i=0
	for f in $FAMS; do
		if [ "$n" -gt 1 ]; then [ "$i" -gt 0 ] && printf '\n'; printf '  %s\n' "$(paint head "IPv$f")"; fi
		local ref=ROWS_$f
		while IFS= read -r line; do
			[ -z "$line" ] && continue
			line=${line#*"$US"}; label=${line%%"$US"*}; cell=${line#*"$US"}
			j=0
			while IFS= read -r part; do
				if [ "$j" = 0 ]; then printf '%s' "$(vpad "  $label" "$LW")"; else printf '%*s' "$LW" ''; fi
				printf '%s\n' "$part"; j=$((j + 1))
			done <<<"${cell//$NL/$'\n'}"
		done <<<"${!ref}"
		i=$((i + 1))
	done
}

# A section title, numbered in the order shown ("一、" in Chinese, "1." in English). With "families", the family names head
# the value columns when they stand side by side or there is only one.
SECTION=0
section() {
	local n line f count=0
	SECTION=$((SECTION + 1))
	if [ "$LANG_UI" = zh ]; then
		case $SECTION in 1) n='一、' ;; 2) n='二、' ;; 3) n='三、' ;; 4) n='四、' ;; 5) n='五、' ;; *) n='六、' ;; esac
	else
		n="$SECTION. "
	fi
	line=$(paint head "$n$1")
	for f in $FAMS; do count=$((count + 1)); done
	if [ "${2-}" = families ] && { [ "$WIDE" = 1 ] || [ "$count" = 1 ]; }; then
		local heads=''
		CW=$(value_width)
		for f in $FAMS; do heads="$heads$(vpad "$(paint head "IPv$f")" "$CW")"; done
		# The family names head the value columns: on the title's line when it leaves room, else on the next one.
		if [ $(($(vwidth "$line") + 1)) -lt "$LW" ]; then line="$(vpad "$line" "$LW")$heads"
		else line="$line"$'\n'"$(printf '%*s' "$LW" '')$heads"; fi
	fi
	printf '\n%s\n' "$line"
}

# A value, its 20-cell scale and a word.
scaled() { printf '%s %s  %s' "$(paint "$2" "$(printf '%-3s' "$1")")" "$(scale "$1" "$3")" "$(paint "$2" "$4")"; }

# 1. IP score: the IPLense score and the purity risk value.
rows_score() {
	local score purity tone level
	score=$(v quick.score)
	purity=$(v quick.purity.value)
	if [ -n "$score" ]; then
		if [ "$score" -ge 80 ]; then level=high; elif [ "$score" -ge 60 ]; then level=medium; else level=low; fi
		row score "IPLense $(l score)" "$(scaled "$score" "$(score_tone "$score")" score "$(l "grade_$level")")"
	fi
	if [ -n "$purity" ]; then
		case $(v quick.purity.state) in good) tone=pos level=low ;; average) tone=neu level=medium ;; *) tone=neg level=high ;; esac
		row purity "$(l purity)" "$(scaled "$purity" "$tone" risk "$(t "risk_$level")")"
	fi
}

# A Quick type label in a column of fixed width, so the names after it start in one column.
type_label() { vpad "$(label "$(quick_type_text "$1")" 0 "$(quick_type_style "$1")")" 6; }

# 2. Basics: the result page's network and location rows, the IP property under the operator.
rows_basics() {
	local name company type nature property human automated i split at bar='' registry nature_style property_style
	name=$(v quick.asn.name) type=$(v quick.asn.type)
	row asn "$(t asn_name)" "${type:+$(type_label "$type") }$(wrap_cell "${name:-$MARK_NONE}" $((CW - 8)))"
	company=$(v quick.company.name) type=$(v quick.company.type)
	row operator "$(l operator)" "${type:+$(type_label "$type") }$(wrap_cell "${company:-$MARK_NONE}" $((CW - 8)))"
	nature=$(v quick.ipNature) property=$(v quick.ipProperty)
	case $nature in Native) nature_style=bpos ;; Broadcast) nature_style=bneu ;; Unknown | '') nature_style=bnone ;; *) nature_style=bneg ;; esac
	case $property in Residential | HomeBroadband | Education | Government) property_style=bpos ;; Business) property_style=bneu ;; Unknown | '') property_style=bnone ;; *) property_style=bneg ;; esac
	row property "$(l ipProperty)" "$(label "$(l "nature_${nature:-Unknown}")" 0 "$nature_style") $(label "$(l "property_${property:-Unknown}")" 0 "$property_style")"
	row number "$(t as_number)" "AS$(v quick.asn.number)"
	human=$(v quick.traffic.humanPercent) automated=$(v quick.traffic.automatedPercent)
	[ -n "$human" ] && human=$(percent "$human")
	[ -n "$automated" ] && automated=$(percent "$automated")
	if [ -n "$human" ]; then
		split=$(awk -v h="$human" 'BEGIN {print int(h / 5)}')
		at=$((split + 1)); [ "$at" -gt 20 ] && at=20
		i=1
		split=$(awk -v h="$human" 'BEGIN {print int(h * 16 / 100)}')
		at=$((split + 1)); [ "$at" -gt 16 ] && at=16
		while [ "$i" -le 16 ]; do
			if [ "$i" = "$at" ]; then bar=$bar$(paint bold "$BAR_AT")
			elif [ "$i" -le "$split" ]; then bar=$bar$(paint pos "$BAR")
			else bar=$bar$(paint head "$BAR"); fi
			i=$((i + 1))
		done
		row traffic "$(l asnTraffic)" "$(paint dim "$(t human)") $(paint pos "$human%") $bar $(paint dim "$(t automated)") $(paint neg "${automated:-$MARK_NONE}%")"
	else
		row traffic "$(l asnTraffic)" "$MARK_NONE"
	fi
	registry=$(v quick.registry)
	row registered "$(t registered_in)" "$(v quick.registrationCountryCode)${registry:+  $(paint dim "$registry")}"
	row used "$(t used_in)" "$(wrap_cell "$(joined_comma "$(v quick.location.city)" "$(v quick.location.region)" "$(v quick.location.country)")" "$CW")"
	if [ "$FULL" = 1 ]; then
		row range "$(l networkRange)" "$(wrap_cell "$(joined "$(v quick.asn.route)" "$(v quick.company.netname)")" "$CW")"
		row ptr "$(l reverseDns)" "$(wrap_cell "$(v reverseDns)" "$CW")"
	fi
}

TY=10
# 3. Multi-source IP types: a row per source with its location and its usage and company types, centred under their headings.
rows_types() {
	local list provider li ti state loc uw cw lw head locs=() k usage company u c
	lw=$((CW - 2 * TY - 2)); [ "$lw" -gt 22 ] && lw=22
	uw=$(width "$(l usageType)") cw=$(width "$(l companyType)")
	head=$(l location)
	row _head "$(paint dim "$(l colSource)")" "$(vpad "$(paint dim "$head")" "$lw")$(vpad "$(paint dim "$(l usageType)")" "$TY" c)$(vpad "$(paint dim "$(l companyType)")" "$TY" c)"
	IFS=$'\n' read -r -d '' -a list < <(providers)
	for provider in "${list[@]}"; do
		li=$(index_of locations "$provider")
		ti=$(index_of types "$provider")
		[ -z "$li$ti" ] && continue
		state=$(provider_state "$provider")
		if [ "$state" != Success ]; then
			module_text "$state"
			row "$provider" "$(paint bold "$(brand "$provider")")" "$(paint "$MS" "$MT")"
			continue
		fi
		loc=''
		if [ -n "$li" ] && [ "$(v "professional.locations.$li.state")" = Success ]; then
			loc=$(joined_comma "$(v "professional.locations.$li.city")" "$(v "professional.locations.$li.countryCode")")
		elif [ -n "$li" ]; then module_text "$(v "professional.locations.$li.state")"; loc=$MT
		fi
		locs=()
		while IFS= read -r k; do locs[${#locs[@]}]=$k; done <<<"$(wrap_text "${loc:-$MARK_NONE}" $((lw - 2)))"
		if [ -n "$ti" ] && [ "$(row_type_state "$ti")" = Success ]; then
			usage=$(v "professional.types.$ti.usageType") company=$(v "professional.types.$ti.companyType")
			u=$(paint none "$MARK_NONE"); c=$u
			[ -n "$usage" ] && u=$(plabel "$(type_text "$usage")" "$(type_style "$usage")" "$uw")
			[ -n "$company" ] && c=$(plabel "$(type_text "$company")" "$(type_style "$company")" "$cw")
			u=$(vpad "$u" "$TY" c) c=$(vpad "$c" "$TY" c)
		elif [ -n "$ti" ]; then module_text "$(row_type_state "$ti")"; u=$(paint "$MS" "$MT") c=''
		else u=$(vpad "$(paint none "$MARK_NONE")" "$TY" c) c=$u; fi
		local cell
		cell="$(vpad "${locs[0]}" "$lw")$u$c"
		k=1
		while [ "$k" -lt "${#locs[@]}" ]; do cell="$cell$NL${locs[$k]}"; k=$((k + 1)); done
		row "$provider" "$(paint bold "$(brand "$provider")")" "$cell"
	done
}

# 4. Multi-source IP risk: each source's risk value and level, and the seven factor marks centred under their headings.
RV=13
rows_risk() {
	local list provider ri column c value level tone marks head w off signals state word
	head=$(l colRiskValue)
	head=$(vpad "$(paint dim "$head")" "$RV")
	for column in $COLUMNS_RISK; do
		w=$(($(width "$(l "column_${column%%:*}")") + 1)); [ "$w" -lt 4 ] && w=4
		head="$head$(vpad "$(paint dim "$(l "column_${column%%:*}")")" "$w")"
	done
	row _head "$(paint dim "$(l colSource)")" "$head"
	IFS=$'\n' read -r -d '' -a list < <(providers)
	for provider in "${list[@]}"; do
		ri=$(index_of riskSources "$provider")
		[ -z "$ri" ] && continue
		state=$(row_risk_state "$ri")
		if [ "$(provider_state "$provider")" != Success ] || [ "$state" != Success ]; then
			module_text "$state"
			row "$provider" "$(paint bold "$(brand "$provider")")" "$(paint "$MS" "$MT")"
			continue
		fi
		value=$(v "professional.riskSources.$ri.score.value")
		level=$(v "professional.riskSources.$ri.score.level")
		if [ -n "$value" ]; then
			value=${value%%.*}; tone=$(risk_tone "$value")
			case $tone in pos) word=$(t risk_low) ;; neu) word=$(t risk_medium) ;; *) word=$(t risk_high) ;; esac
			value="$value $word"
		elif [ -n "$level" ]; then
			level=$(printf '%s' "$level" | tr '[:upper:]' '[:lower:]')
			case $level in low) tone=pos ;; medium) tone=neu ;; *) level=high tone=neg ;; esac
			value=$(t "risk_$level")
		else value=$MARK_NONE tone=none; fi
		marks=$(vpad "$(paint "$tone" "$value")" "$RV")
		signals=$(signal_states "$ri")
		for column in $COLUMNS_RISK; do
			w=$(($(width "$(l "column_${column%%:*}")") + 1)); [ "$w" -lt 4 ] && w=4
			off=$((($(width "$(l "column_${column%%:*}")") - 1) / 2))
			case $(risk_mark "$signals" "${column#*:}") in
			detected) c=$(paint neg "$MARK_HIT") ;; clear) c=$(paint pos "$MARK_CLEAR") ;; *) c=$(paint none "$MARK_NONE") ;;
			esac
			marks="$marks$(printf '%*s' "$off" '')$(vpad "$c" $((w - off)))"
		done
		row "$provider" "$(paint bold "$(brand "$provider")")" "$marks"
	done
}

# A provider's state across its modules: Success when any of them succeeded, else QuotaUnavailable or Error.
provider_state() {
	local li ti ri states=''
	li=$(index_of locations "$1")
	ti=$(index_of types "$1")
	ri=$(index_of riskSources "$1")
	[ -n "$li" ] && states="$states $(v "professional.locations.$li.state")"
	[ -n "$ti" ] && states="$states $(row_type_state "$ti")"
	[ -n "$ri" ] && states="$states $(row_risk_state "$ri")"
	case " $states " in *Success*) printf Success ;; *Quota*) printf QuotaUnavailable ;; *) printf Error ;; esac
}

# A module that did not answer, as text and style in MT and MS.
module_text() {
	case $1 in
	QuotaUnavailable) MT=$(l quotaUnavailable) MS=neu ;;
	*) MT=$(l error) MS=neg ;;
	esac
}

# A module state of a type row: quota or failure in either field stands for the whole row (as on the web).
row_type_state() {
	local all
	all="$(v "professional.types.$1.state") $(v "professional.types.$1.usageState") $(v "professional.types.$1.companyState")"
	case $all in *QuotaUnavailable*) printf QuotaUnavailable ;; *Error*) printf Error ;; *) printf Success ;; esac
}

row_risk_state() {
	local all
	all="$(v "professional.riskSources.$1.state") $(v "professional.riskSources.$1.score.state") $(v "professional.riskSources.$1.score.scoreOrigin")"
	case $all in *QuotaUnavailable*) printf QuotaUnavailable ;; *Error*) printf Error ;; *) printf Success ;; esac
}

# The risk matrix: one row per answering source, seven columns grouped from its signals as on the web.
COLUMNS_RISK='hosting:hosting,cloud proxy:proxy,residentialProxy vpn:vpn tor:tor,torExit relay:relay abuse:abuse,abuser,attacker,spam,scanner,compromised,botnet,threat bot:scraper,maliciousBot,bot'

# A source's signals as ",key:state,key:state,".
signal_states() {
	local j=0 key out=,
	while :; do
		key=$(v "professional.riskSources.$1.signals.$j.canonicalKey")
		[ -z "$key" ] && break
		out="$out$key:$(v "professional.riskSources.$1.signals.$j.state"),"
		j=$((j + 1))
	done
	printf '%s' "$out"
}

# Detected when any of the column's signals is, clear when a reported one is not, none when the source reports none.
risk_mark() {
	local found=none key IFS=,
	for key in $2; do
		case $1 in *",$key:Detected,"*) printf detected; return ;; *",$key:NotDetected,"*) found=clear ;; esac
	done
	printf '%s' "$found"
}

# The matrix's legend, once under the section.
render_legend() {
	printf '  %s %s   %s %s   %s %s\n' "$(paint neg "$MARK_HIT")" "$(paint dim "$(l cell_detected)")" "$(paint pos "$MARK_CLEAR")" \
		"$(paint dim "$(l cell_clear)")" "$(paint none "$MARK_NONE")" "$(paint dim "$(l cell_none)")"
}

# The report: header, report link, then the sections that have results.
render_report() {
	local family count=0
	for family in $RESULTS; do count=$((count + 1)); done
	render_header
	[ -n "$REPORT_LINES" ] && printf '%s\n' "$REPORT_LINES"
	for family in $FAMILIES; do
		case " $RESULTS " in *" $family "*) ;; *) render_failure "$family" ;; esac
	done
	FAMS=${RESULTS# }
	WIDE=0
	[ "$count" = 2 ] && [ "$COLS" -ge 120 ] && WIDE=1
	if [ "$count" -gt 0 ]; then
		F=${FAMS%% *}
		section "$(t section_score)" families; emit rows_score
		section "$(t section_basics)" families; emit rows_basics
		section "$(t section_types)" families; emit rows_types
		section "$(t section_risk)" families; emit rows_risk; render_legend
	fi
	[ -n "$LOCAL_FAMILY" ] && render_local
	render_footer
}

render_footer() {
	printf '\n%s\n' "$(paint dim "$(repeat "$BOX_H" "$COLS")")"
}

# A platform's result for one family: sets STATUS and REGION ("" when it has none).
platform_result() {
	local ref=LOCAL_RESULTS_$1 row
	STATUS='' REGION=''
	while IFS= read -r row; do
		split_result "$row"
		[ "$KEY" = "$2" ] && return
	done <<<"${!ref}"
	STATUS='' REGION=''
}

# A platform result as a label: unlocked green, blocked red, partial amber, failed grey.
unlock_label() {
	case $1 in
	available | supported | region) printf '%s\t%s' "$(t unlocked)" bpos ;;
	unavailable | unsupported) printf '%s\t%s' "$(t blocked)" bneg ;;
	originals_only) printf '%s\t%s' "$(t originals_only)" bneu ;;
	*) printf '%s\t%s' "$(t failed)" bnone ;;
	esac
}

# 5. AI and streaming: platforms as columns, a label row and a region row per family, all starting at the column's left edge
# (as in 1.2); a column is as wide as its name or widest label and two spaces. A platform with no address in a family leaves
# that cell empty; one with none in any family shown is left out.
render_platforms() {
	local key keys='' family n i names text style lw=8 line regions has
	for key in $PLATFORMS; do
		has=0
		for family in $LOCAL_FAMILIES; do platform_result "$family" "$key"; [ -n "$STATUS" ] && [ "$STATUS" != no_ipv6 ] && has=1; done
		[ "$has" = 1 ] && keys="$keys $key"
	done
	set -f
	local -a plist widths=()
	read -r -a plist <<<"$keys"
	set +f
	n=${#plist[@]}
	# A column is its name or its widest label (two wider than the word), and two columns between platforms.
	i=0
	while [ "$i" -lt "$n" ]; do
		widths[i]=$(width "$(local_name "${plist[$i]}")")
		for family in $LOCAL_FAMILIES; do
			platform_result "$family" "${plist[$i]}"
			[ -z "$STATUS" ] || [ "$STATUS" = no_ipv6 ] && continue
			IFS=$'\t' read -r text style <<<"$(unlock_label "$STATUS")"
			widths[i]=$(max "${widths[$i]}" $(($(width "$text") + 2)))
		done
		widths[i]=$((widths[i] + 2))
		i=$((i + 1))
	done
	i=0
	while [ "$i" -lt "$n" ]; do
		# As many platforms as fit the line, at most six.
		local used=$lw k=$i
		while [ "$k" -lt "$n" ] && [ $((k - i)) -lt 6 ] && [ $((used + widths[k])) -le "$COLS" ]; do used=$((used + widths[k])); k=$((k + 1)); done
		[ "$k" = "$i" ] && k=$((i + 1))
		[ "$i" -gt 0 ] && printf '\n'
		names=$(printf '%*s' "$lw" '')
		local j=$i
		while [ "$j" -lt "$k" ]; do names="$names$(vpad "$(paint bold "$(local_name "${plist[$j]}")")" "${widths[$j]}")"; j=$((j + 1)); done
		printf '%s\n' "$names"
		for family in $LOCAL_FAMILIES; do
			line=$(vpad "  $(paint head "IPv$family")" "$lw") regions=$(printf '%*s' "$lw" '')
			j=$i
			while [ "$j" -lt "$k" ]; do
				key=${plist[$j]}
				platform_result "$family" "$key"
				if [ -z "$STATUS" ] || [ "$STATUS" = no_ipv6 ]; then
					line="$line$(printf '%*s' "${widths[$j]}" '')" regions="$regions$(printf '%*s' "${widths[$j]}" '')"
				else
					IFS=$'\t' read -r text style <<<"$(unlock_label "$STATUS")"
					line="$line$(vpad "$(label "$text" 0 "$style")" "${widths[$j]}")"
					regions="$regions$(vpad " $(paint dim "$REGION")" "${widths[$j]}")"
				fi
				j=$((j + 1))
			done
			printf '%s\n%s\n' "$line" "$regions"
		done
		i=$k
	done
}

# 6. Outbound port 25 per family; where it is open, each mail provider's server after it, wrapped under the first.
render_port25() {
	local family line badge entry key state name text style indent=17
	for family in $LOCAL_FAMILIES; do
		platform_result "$family" port25
		case $STATUS in available) text=$(t port_open) style=bpos ;; unavailable) text=$(t blocked) style=bneg ;; *) text=$(t failed) style=bnone ;; esac
		line="$(vpad "  $(paint head "IPv$family")" 8)$(vpad "$(label "$text" 0 "$style")" 9)"
		platform_result "$family" mail
		if [ -n "$STATUS" ]; then
			for entry in $STATUS $REGION; do
				key=${entry%%:*} state=${entry#*:}
				[ "$state" = no_ipv6 ] && continue
				name=$(mail_name "$key")
				case $state in open) style=bpos ;; closed) style=bneg ;; *) style=bnone ;; esac
				badge="$(label "$name" 0 "$style") "
				if [ $(($(vwidth "$line") + $(vwidth "$badge"))) -gt "$COLS" ]; then
					printf '%s\n' "$line"
					line=$(printf '%*s' "$indent" '')
				fi
				line="$line$badge"
			done
		fi
		printf '%s\n' "$line"
	done
}

mail_name() {
	case $1 in
	gmail) printf Gmail ;; outlook) printf Outlook ;; yahoo) printf Yahoo ;; apple) printf Apple ;; qq) printf QQ ;; mailru) printf Mail.ru ;;
	aol) printf AOL ;; gmx) printf GMX ;; mailcom) printf Mail.com ;; netease) printf 163 ;; sohu) printf Sohu ;; sina) printf Sina ;;
	esac
}

load_local() {
	LOCAL_FAMILY=$1
	local ref=LOCAL_RESULTS_$1
	LOCAL_RESULTS=${!ref}
	ref=LOCAL_EXIT_$1; LOCAL_EXIT=${!ref}
	ref=CHECKED_IP_$1; CHECKED_IP=${!ref}
}

# Sections five and six; a family whose platforms saw a different exit than the IP checked says so first.
render_local() {
	local family
	section "$(t platforms)"
	for family in $LOCAL_FAMILIES; do
		load_local "$family"
		if [ -n "$LOCAL_EXIT" ] && [ -n "$CHECKED_IP" ] && [ "$LOCAL_EXIT" != "$CHECKED_IP" ]; then
			printf '  %s  %s\n' "$(paint head "IPv$family")" "$(paint neu "$(tf local_exit "$(display_ip "$LOCAL_EXIT")")")"
			printf '        %s\n' "$(paint dim "$(t local_exit_note)")"
		fi
	done
	render_platforms
	section "$(t port25)"
	render_port25
}


# ---------------------------------------------------------------------------------------------------------------------
# Local checks: what AI and streaming platforms and a mail server answer this machine. Each reads one to three responses
# and reports only what a response states; anything else is "check failed". Report creation uploads only the bounded local-result contract.
#
# Markers taken from two AGPL-3.0 projects, whose copyright stays with their authors:
#   xykt/IPQuality (https://github.com/xykt/IPQuality) and lmc999/RegionRestrictionCheck
#   (https://github.com/lmc999/RegionRestrictionCheck). Each check below names the one it follows.

UA_BROWSER='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36'
# The public client key built into Disney+'s own web player, as both projects above send it; not an IPLense credential.
DISNEY_WEB_CLIENT_KEY='ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84'
SMTP_HOST=gmail-smtp-in.l.google.com
# ISO 3166-1 alpha-3 to alpha-2, from the Debian iso-codes list (2026-10-05 snapshot): Gemini states its region in three
# letters, every other check in two.
ALPHA3_TO_ALPHA2='ABW:AW AFG:AF AGO:AO AIA:AI ALA:AX ALB:AL AND:AD ARE:AE ARG:AR ARM:AM ASM:AS ATA:AQ ATF:TF ATG:AG AUS:AU AUT:AT
AZE:AZ BDI:BI BEL:BE BEN:BJ BES:BQ BFA:BF BGD:BD BGR:BG BHR:BH BHS:BS BIH:BA BLM:BL BLR:BY BLZ:BZ BMU:BM BOL:BO
BRA:BR BRB:BB BRN:BN BTN:BT BVT:BV BWA:BW CAF:CF CAN:CA CCK:CC CHE:CH CHL:CL CHN:CN CIV:CI CMR:CM COD:CD COG:CG
COK:CK COL:CO COM:KM CPV:CV CRI:CR CUB:CU CUW:CW CXR:CX CYM:KY CYP:CY CZE:CZ DEU:DE DJI:DJ DMA:DM DNK:DK DOM:DO
DZA:DZ ECU:EC EGY:EG ERI:ER ESH:EH ESP:ES EST:EE ETH:ET FIN:FI FJI:FJ FLK:FK FRA:FR FRO:FO FSM:FM GAB:GA GBR:GB
GEO:GE GGY:GG GHA:GH GIB:GI GIN:GN GLP:GP GMB:GM GNB:GW GNQ:GQ GRC:GR GRD:GD GRL:GL GTM:GT GUF:GF GUM:GU GUY:GY
HKG:HK HMD:HM HND:HN HRV:HR HTI:HT HUN:HU IDN:ID IMN:IM IND:IN IOT:IO IRL:IE IRN:IR IRQ:IQ ISL:IS ISR:IL ITA:IT
JAM:JM JEY:JE JOR:JO JPN:JP KAZ:KZ KEN:KE KGZ:KG KHM:KH KIR:KI KNA:KN KOR:KR KWT:KW LAO:LA LBN:LB LBR:LR LBY:LY
LCA:LC LIE:LI LKA:LK LSO:LS LTU:LT LUX:LU LVA:LV MAC:MO MAF:MF MAR:MA MCO:MC MDA:MD MDG:MG MDV:MV MEX:MX MHL:MH
MKD:MK MLI:ML MLT:MT MMR:MM MNE:ME MNG:MN MNP:MP MOZ:MZ MRT:MR MSR:MS MTQ:MQ MUS:MU MWI:MW MYS:MY MYT:YT NAM:NA
NCL:NC NER:NE NFK:NF NGA:NG NIC:NI NIU:NU NLD:NL NOR:NO NPL:NP NRU:NR NZL:NZ OMN:OM PAK:PK PAN:PA PCN:PN PER:PE
PHL:PH PLW:PW PNG:PG POL:PL PRI:PR PRK:KP PRT:PT PRY:PY PSE:PS PYF:PF QAT:QA REU:RE ROU:RO RUS:RU RWA:RW SAU:SA
SDN:SD SEN:SN SGP:SG SGS:GS SHN:SH SJM:SJ SLB:SB SLE:SL SLV:SV SMR:SM SOM:SO SPM:PM SRB:RS SSD:SS STP:ST SUR:SR
SVK:SK SVN:SI SWE:SE SWZ:SZ SXM:SX SYC:SC SYR:SY TCA:TC TCD:TD TGO:TG THA:TH TJK:TJ TKL:TK TKM:TM TLS:TL TON:TO
TTO:TT TUN:TN TUR:TR TUV:TV TWN:TW TZA:TZ UGA:UG UKR:UA UMI:UM URY:UY USA:US UZB:UZ VAT:VA VCT:VC VEN:VE VGB:VG
VIR:VI VNM:VN VUT:VU WLF:WF WSM:WS YEM:YE ZAF:ZA ZMB:ZM ZWE:ZW'
LOCAL_CHECKS='chatgpt claude gemini grok netflix disney prime hbo paramount tiktok reddit port25'
PLATFORMS='chatgpt claude gemini grok netflix disney prime hbo paramount tiktok reddit'

# One request over the local checks' family; sets PAGE (the body) and PAGE_STATUS ("<code> <final URL>", empty on failure).
page() {
	local out
	out=$(curl "-$LOCAL_FAMILY" -sS -L --connect-timeout 8 --max-time 10 -A "$UA_BROWSER" -H 'Accept-Language: en' "$@" \
		-w '\n%{http_code} %{url_effective}' 2>/dev/null)
	PAGE_RC=$?
	PAGE_STATUS=${out##*$'\n'}
	PAGE=${out%$'\n'*}
	if [ "$PAGE_RC" -ne 0 ] || [ "${PAGE_STATUS%% *}" = 000 ]; then PAGE_STATUS=; PAGE=; fi
}

# A check that got no answer: over IPv6, curl's "could not resolve" (6) means the platform has no IPv6 address at all, which is
# not this IP's fault and is left out of the report; anything else is a failed check.
fail() {
	if [ "$LOCAL_FAMILY" = 6 ] && [ "${PAGE_RC-}" = 6 ]; then printf 'no_ipv6'; else printf 'failed'; fi
}

# The first capture of a regular expression in PAGE, or nothing.
match() {
	local re=$1
	if [[ $PAGE =~ $re ]]; then printf '%s' "${BASH_REMATCH[1]}"; fi
}

# Each distinct capture GROUP of a regular expression in PAGE, one per line, in the order they first appear. grep finds the
# matches, since cutting a page of several hundred kilobytes with bash's own patterns takes minutes on bash 3.2.
matches() {
	local re=$1 group=$2 line seen=$'\n'
	while IFS= read -r line; do
		[[ $line =~ $re ]] || continue
		case $seen in *$'\n'"${BASH_REMATCH[$group]}"$'\n'*) ;; *) seen+=${BASH_REMATCH[$group]}$'\n' ;; esac
	done < <(printf '%s' "$PAGE" | grep -oE -- "$re" 2>/dev/null)
	printf '%s' "${seen#$'\n'}"
}

# The only line of a list, or nothing when it has none or several.
single() {
	local list=${1%$'\n'}
	case $list in *$'\n'*) ;; *) printf '%s' "$list" ;; esac
}

# A URL's host in lower case (no user, port, path or query), and its path (no query or fragment).
url_host() {
	local authority=${1#*://}
	[ "$authority" = "$1" ] && return
	authority=${authority%%[/?#]*}
	authority=${authority##*@}
	printf '%s' "${authority%%:*}" | tr '[:upper:]' '[:lower:]'
}
url_path() {
	local rest=${1#*://} path=/
	case $rest in */*) path=/${rest#*/} ;; esac
	printf '%s' "${path%%[?#]*}"
}

# The first answer to a request over the local checks' family, without following a redirect: "<code> <redirect URL>",
# empty on a failed connection.
first_hop() {
	local out
	out=$(curl "-$LOCAL_FAMILY" -sS -o /dev/null --connect-timeout 8 --max-time 10 -A "$UA_BROWSER" -H 'Accept-Language: en' \
		-w '%{http_code} %{redirect_url}' "$1" 2>/dev/null) || return 0
	[ "${out%% *}" = 000 ] || printf '%s' "$out"
}

# A check's answer: "status region", status one of available, unavailable, failed, supported, unsupported, originals_only.
# The AI checks add a second line with the address the platform's trace saw (its ip= field), the exit the platforms see.
check_ai() {
	local platform=$1 host=$2 region list exit answer
	page "https://$host/cdn-cgi/trace"
	exit=$(match $'\nip=([0-9A-Fa-f.:]+)')
	region=$(match $'\nloc=([A-Z]{2})')
	list=$(ai_list "$platform")
	if [ -z "$region" ]; then answer=$(fail)
	elif [ -z "$list" ]; then answer="region $region"
	elif case ",$list," in *",$region,"*) true ;; *) false ;; esac; then answer="supported $region"
	else answer="unsupported $region"; fi
	printf '%s' "$answer"
	[ -n "$exit" ] && printf '\n%s' "$exit"
}

# Gemini: Google serves pages with and without its old experiment flags in every region, so the page alone cannot tell. Google's
# own location verdict is NotebookLM's first redirect, asked over the same family: to location=unsupported where it is not
# offered, to notebook.google.com where it is. A region Google restricts, stated on the page, outranks every other signal
# (a China-located server once showed CHN with the old flag set and no Gemini). The region shown is the page's, when it
# states exactly one.
check_gemini() {
	local regions region blocked verdict target='' flag=''
	page https://gemini.google.com/
	[ -z "$PAGE_STATUS" ] && { fail; return; }
	case $(url_path "${PAGE_STATUS#* }") in /sorry | /sorry/*) fail; return ;; esac
	case ${PAGE_STATUS%% *} in 403 | 451) printf 'unavailable'; return ;; 2??) ;; *) fail; return ;; esac
	[ -z "$PAGE" ] && { fail; return; }
	regions=$(matches '(,2,1,200,|\[1,null,null,[0-9]+,[0-9]+,)\\?"([A-Z]{3})\\?"' 2)
	for blocked in AFG CHN RUS BLR CUB IRN PRK SYR; do
		case $'\n'$regions$'\n' in *$'\n'$blocked$'\n'*) printf 'unavailable %s' "$(alpha2 "$blocked")"; return ;; esac
	done
	region=$(single "$regions")
	[ -n "$region" ] && region=$(alpha2 "$region")
	if [[ $PAGE == *'45631641,null,true'* || $PAGE == *'45617354,null,true'* ]]; then flag=true
	elif [[ $PAGE == *'45631641,null,false'* || $PAGE == *'45617354,null,false'* ]]; then flag=false; fi
	verdict=$(first_hop https://notebooklm.google.com/)
	case ${verdict%% *} in 3??) target=${verdict#* } ;; esac
	if [[ $target == *location=unsupported* ]] || [ "$flag" = false ]; then printf 'unavailable%s' "${region:+ $region}"
	elif [ "$flag" = true ]; then printf 'available%s' "${region:+ $region}"
	else
		case $(url_host "$target") in
		notebook.google.com | notebooklm.google.com) printf 'available%s' "${region:+ $region}" ;;
		*) fail ;;
		esac
	fi
}

# The two-letter code for a three-letter one; a code not in the list is shown as it is.
alpha2() {
	local table=" ${ALPHA3_TO_ALPHA2//$'\n'/ } "
	case $table in
	*" $1:"*) table=${table#*" $1:"}; printf '%s' "${table%% *}" ;;
	*) printf '%s' "$1" ;;
	esac
}

# Netflix (IPQuality): a Netflix original and a licensed title; "Oh no!" marks a title this region cannot watch.
check_netflix() {
	local region original licensed
	page https://www.netflix.com/title/81280792
	[ -z "$PAGE_STATUS" ] && { fail; return; }
	original=$PAGE_STATUS
	[[ $PAGE == *'Oh no!'* ]] && original=no
	region=$(match '"id":"([A-Z]{2})","countryName"')
	page https://www.netflix.com/title/70143836
	[ -z "$PAGE_STATUS" ] && { fail; return; }
	licensed=$PAGE_STATUS
	[[ $PAGE == *'Oh no!'* ]] && licensed=no
	[ -z "$region" ] && region=$(match '"id":"([A-Z]{2})","countryName"')
	if [ "${original%% *}" = 403 ] || { [ "$original" = no ] && [ "$licensed" = no ]; }; then printf 'unavailable'
	elif [ "$licensed" = no ] && [ -n "$region" ]; then printf 'originals_only %s' "$region"
	elif [ "${licensed%% *}" = 200 ] && [ -n "$region" ]; then printf 'available %s' "$region"
	else fail; fi
}

# Disney+: the live GraphQL registerDevice response supplies extensions.sdk.session's country and support flag.
# The legacy devices -> token exchange intermittently returns invalid_grant/invalid-token even for a newly issued
# assertion. Use the directly observed registration contract, one request, with a fixed generic browser description.
check_disney() {
	local region supported
	# shellcheck disable=SC2016 # $input is a GraphQL variable, sent literally.
	page https://disney.api.edge.bamgrid.com/graph/v1/device/graphql -X POST -H "authorization: $DISNEY_WEB_CLIENT_KEY" \
		-H 'Content-Type: application/json' \
		-d '{"query":"mutation registerDevice($input: RegisterDeviceInput!) { registerDevice(registerDevice: $input) { grant { grantType } } }","variables":{"input":{"deviceFamily":"browser","applicationRuntime":"chrome","deviceProfile":"windows","deviceLanguage":"en","attributes":{"operatingSystem":"windows","operatingSystemVersion":"10.0"}}}}'
	[ "${PAGE_STATUS%% *}" = 200 ] || { fail; return; }
	region=$(match '"countryCode" *: *"([A-Z]{2})"')
	supported=$(match '"inSupportedLocation" *: *(true|false)')
	if [ -n "$region" ] && [ "$supported" = true ]; then printf 'available %s' "$region"
	elif [ -n "$region" ] && [ "$supported" = false ]; then printf 'unavailable %s' "$region"
	else fail; fi
}

# TikTok (IPQuality): the explore page states the visitor's region (the home page answers curl with a challenge).
check_tiktok() {
	local region
	page https://www.tiktok.com/explore --compressed -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
	region=$(match '"region":"([A-Z]{2})"')
	if [ -n "$region" ]; then printf 'available %s' "$region"; else fail; fi
}

# Prime Video (RegionRestrictionCheck, IPQuality): the home page flags a restricted service, else states the current territory.
check_prime() {
	local region
	page https://www.primevideo.com
	[ -z "$PAGE_STATUS" ] && { fail; return; }
	region=$(match '"currentTerritory":"([A-Z]{2})"')
	if [[ $PAGE == *isServiceRestricted* ]]; then printf 'unavailable%s' "${region:+ $region}"
	elif [ -n "$region" ]; then printf 'available %s' "$region"; else fail; fi
}

# Grok: grok.com answers 200 where it serves the visitor and 403 or 451 where it does not; the region is the one its own trace
# states (Grok has no official region list to compare with).
check_grok() {
	local region code
	page https://grok.com/cdn-cgi/trace
	[ -z "$PAGE_STATUS" ] && { fail; return; }
	region=$(match $'\nloc=([A-Z]{2})')
	page https://grok.com/
	code=${PAGE_STATUS%% *}
	case $code in
	2??) printf 'available%s' "${region:+ $region}" ;;
	403 | 451) printf 'unavailable%s' "${region:+ $region}" ;;
	*) fail ;;
	esac
}

# HBO Max (RegionRestrictionCheck, updated for the 2025 domain): the home page sets a countryCode cookie for the visitor and
# lists the regions it serves; a country outside that list cannot subscribe.
check_hbo() {
	local region list
	page https://www.hbomax.com/ -D -
	[ -z "$PAGE_STATUS" ] && { fail; return; }
	region=$(match $'[Ss]et-[Cc]ookie: countryCode=([A-Za-z]{2})')
	region=$(printf '%s' "$region" | tr '[:lower:]' '[:upper:]')
	list=$(matches '"countryCode":"([a-z]{2})"' 1 | tr '[:lower:]' '[:upper:]')
	[ -z "$region" ] || [ -z "$list" ] && { fail; return; }
	case $'\n'$list$'\nUS\n' in *$'\n'"$region"$'\n'*) printf 'available %s' "$region" ;; *) printf 'unavailable %s' "$region" ;; esac
}

# Paramount+ (RegionRestrictionCheck): a visitor outside its regions is sent to /intl; 403 and 406 refuse the network.
check_paramount() {
	local region
	page https://www.paramountplus.com/
	[ -z "$PAGE_STATUS" ] && { fail; return; }
	region=$(url_path "${PAGE_STATUS#* }")
	region=${region#/}; region=${region%%/*}
	case ${PAGE_STATUS%% *}:$region in
	*:intl | 403:* | 406:*) printf 'unavailable' ;;
	200:[a-z][a-z]) printf 'available %s' "$(printf '%s' "$region" | tr '[:lower:]' '[:upper:]')" ;;
	200:*) printf 'available US' ;;
	*) fail ;;
	esac
}

# Reddit (IPQuality): the chat shell answers 200 with the visitor's country, or 403 where Reddit blocks the network.
check_reddit() {
	page https://www.reddit.com/svc/shreddit/reddit-chat
	case ${PAGE_STATUS%% *} in
	200) printf 'available %s' "$(match 'country="([A-Z]{2})"')" ;;
	403) printf 'unavailable' ;;
	*) fail ;;
	esac
}

# NETWORK_REDIRECTIONS enables /dev/tcp and /dev/udp together in Bash. Opening a numeric UDP socket tests the compiled
# feature without sending a packet, resolving a name or relying on a listener or translated error messages.
has_net_redirections() { ( : <>/dev/udp/127.0.0.1/9 ) 2>/dev/null; }

# Resolve before connecting. getent hosts is provided by glibc and Alpine's musl-utils; macOS uses its system resolver.
# Select an address of the tested family. An absent address means this machine cannot initiate that test.
smtp_address() {
	local records address rest field
	case $(uname -s) in
	Darwin)
		field=ipv6_address; [ "$LOCAL_FAMILY" = 4 ] && field=ip_address
		records=$(dscacheutil -q host -a name "$SMTP_HOST" 2>/dev/null | sed -n "s/^$field: //p") ;;
	*) records=$(getent ahosts "$SMTP_HOST" 2>/dev/null | awk '{print $1}') ;;
	esac
	while IFS=' ' read -r address rest; do
		case $LOCAL_FAMILY:$address in
		4:*.*) case $address in *:*) continue ;; esac ;;
		6:*:*) ;;
		*) continue ;;
		esac
		printf '%s' "$address"; return
	done <<<"$records"
}

# The connection has its own five-second deadline. Once connected, Bash read gives the greeting a full five seconds.
# The same Bash executable is used, including macOS 3.2. No mail commands other than QUIT are sent.
smtp_greeting() {
	# shellcheck disable=SC2016 # This code executes in the child Bash.
	"$BASH" -c '
		(sleep 5; kill -TERM "$$" 2>/dev/null) &
		timer=$!
		trap '"'"'kill "$timer" 2>/dev/null'"'"' EXIT
		exec 3<>"/dev/tcp/$1/${2:-25}" || exit 1
		kill "$timer" 2>/dev/null
		wait "$timer" 2>/dev/null
		trap - EXIT
		IFS= read -r -t 5 line <&3 || exit 2
		printf "QUIT\r\n" >&3
		printf "%s" "$line"
	' _ "$SMTP_ADDRESS" "${SMTP_PORT:-25}" 2>/dev/null
}

check_port25() {
	local greeting
	has_net_redirections || { printf 'failed'; return; }
	SMTP_ADDRESS=$(smtp_address)
	[ -n "$SMTP_ADDRESS" ] || { printf 'failed'; return; }
	greeting=$(smtp_greeting)
	case $greeting in 220[\ -]*) printf 'available' ;; *) printf 'unavailable' ;; esac
}

# Mail providers (IPQuality's list): each domain's preferred mail server, looked up over DNS-over-HTTPS (no dig or nslookup is
# assumed), is opened on port 25 over this family and must greet with 220. Run only where outbound port 25 is open; all twelve
# at once, so the wait is one connection's. A provider whose server has no address in this family is "no_ipv6".
MAIL_PROVIDERS='gmail:gmail.com outlook:outlook.com yahoo:yahoo.com apple:icloud.com qq:qq.com mailru:mail.ru aol:aol.com gmx:gmx.com mailcom:mail.com netease:163.com sohu:sohu.com sina:sina.com'

mail_exchanger() {
	curl "-$LOCAL_FAMILY" -sS --connect-timeout 5 --max-time 8 -H 'Accept: application/dns-json' "https://cloudflare-dns.com/dns-query?name=$1&type=MX" 2>/dev/null |
		grep -oE '"data": ?"[0-9]+ [^"]+"' | sed -E 's/"data": ?"//; s/"$//; s/\.$//' | sort -n | head -1 | awk '{print $2}'
}

check_mail_provider() {
	local key=${1%%:*} domain=${1#*:} greeting
	SMTP_HOST=$(mail_exchanger "$domain")
	[ -n "$SMTP_HOST" ] || { printf '%s:failed' "$key"; return; }
	SMTP_ADDRESS=$(smtp_address)
	if [ -z "$SMTP_ADDRESS" ]; then
		if [ "$LOCAL_FAMILY" = 6 ]; then printf '%s:no_ipv6' "$key"; else printf '%s:failed' "$key"; fi
		return
	fi
	greeting=$(smtp_greeting)
	case $greeting in 220[\ -]*) printf '%s:open' "$key" ;; *) printf '%s:closed' "$key" ;; esac
}

check_mail() {
	local provider out
	out=$(for provider in $MAIL_PROVIDERS; do (printf '%s\n' "$(check_mail_provider "$provider")") & done; wait)
	# Back in the list's order, whatever order the connections finished in.
	for provider in $MAIL_PROVIDERS; do
		provider=${provider%%:*}
		printf ' %s' "$(printf '%s\n' "$out" | grep -m1 "^$provider:")"
	done
}

# Only -f asks the system resolver for a PTR; no host name is uploaded in a report.
reverse_dns() {
	case $(uname -s) in
	Darwin) dscacheutil -q host -a ip_address "$1" 2>/dev/null | sed -n 's/^name: //p' ;;
	*) getent hosts "$1" 2>/dev/null | awk '{print $2}' ;;
	esac
}

# The official supported-region list for one AI platform, from the server's result over either family.
ai_list() {
	local name
	for name in "K4_aiRegions__$1" "K6_aiRegions__$1"; do
		if [ -n "${!name-}" ]; then printf '%s' "${!name}"; return; fi
	done
	printf '%s' "${AI_JSON_LISTS-}" | sed -n "s/^$1=//p"
}

local_name() {
	case $1 in
	chatgpt) printf ChatGPT ;; claude) printf Claude ;; gemini) printf Gemini ;; grok) printf Grok ;; netflix) printf Netflix ;;
	disney) printf 'Disney+' ;; prime) printf Prime ;; hbo) printf HBO ;;
	paramount) printf 'Paramount+' ;; tiktok) printf TikTok ;; reddit) printf Reddit ;; port25) t port25 ;; mail) t mail_progress ;;
	esac
}

# Runs every check; sets LOCAL_RESULTS to one "key status region" line each.
run_local() {
	local key n=0 total=0
	for key in $LOCAL_CHECKS; do total=$((total + 1)); done
	LOCAL_RESULTS=''
	LOCAL_EXIT=''
	local answer
	for key in $LOCAL_CHECKS; do
		n=$((n + 1))
		progress "$(tf local_progress "$(local_name "$key")" "$n" "$total")"
		case $key in
		chatgpt | claude)
			if [ "$key" = chatgpt ]; then answer=$(check_ai chatgpt chatgpt.com); else answer=$(check_ai claude claude.ai); fi
			# The second line, when present, is the exit the platform's trace saw; the first one found is kept.
			case $answer in *$'\n'*) [ -z "$LOCAL_EXIT" ] && LOCAL_EXIT=${answer#*$'\n'}; answer=${answer%%$'\n'*} ;; esac
			LOCAL_RESULTS="$LOCAL_RESULTS$key $answer"$'\n'
			;;
		*) LOCAL_RESULTS="$LOCAL_RESULTS$key $("check_$key")"$'\n' ;;
		esac
	done
	# Where outbound 25 is open, each mail provider's own server.
	case $'\n'$LOCAL_RESULTS in
	*$'\nport25 available\n'*)
		progress "$(t mail_progress)"
		LOCAL_RESULTS="${LOCAL_RESULTS}mail$(check_mail)"$'\n'
		;;
	esac
	clear_progress
}

# Splits one LOCAL_RESULTS line into KEY, STATUS and REGION.
split_result() {
	KEY=${1%% *}
	local rest=${1#* }
	STATUS=${rest%% *}
	REGION=
	[ "$rest" != "$STATUS" ] && REGION=${rest#* }
}

local_json() {
	local row out='' entry mail='' IFS=$'\n'
	set -f
	for row in $LOCAL_RESULTS; do
		split_result "$row"
		if [ "$KEY" = mail ]; then
			IFS=' '
			for entry in $STATUS $REGION; do mail="$mail,\"${entry%%:*}\":\"${entry#*:}\""; done
			IFS=$'\n'
			out="$out,\"mail\":{${mail#,}}"
		else
			out="$out,\"$KEY\":{\"status\":\"$STATUS\",\"region\":\"$REGION\"}"
		fi
	done
	set +f
	printf '{"family":%s,"exitIp":"%s"%s}' "$LOCAL_FAMILY" "$(display_ip "$LOCAL_EXIT")" "$out"
}

# ---------------------------------------------------------------------------------------------------------------------
# Main

# Whether the output goes to a terminal: colour and the terminal's width are used only then.
on_terminal() {
	[ -t 1 ]
}

progress() {
	if on_terminal && [ -t 2 ] && [ "$JSON" = 0 ] && [ -z "$OUT" ]; then printf '\r\033[K%s' "$1" >&2; fi
}
clear_progress() {
	if on_terminal && [ -t 2 ] && [ "$JSON" = 0 ] && [ -z "$OUT" ]; then printf '\r\033[K' >&2; fi
}

# Drop one family from LOCAL_FAMILIES (word by word: bash 3.2 ignores a quoted pattern with a space in ${var%...}).
drop_local_family() {
	local f out=''
	for f in $LOCAL_FAMILIES; do [ "$f" = "$1" ] || out="$out $f"; done
	LOCAL_FAMILIES=$out
}

# Upload only the report contract; -f never changes the masked exit sent here.
report_local_json() {
	local row out='' port=failed differs=false exit='' mail='' entry key status
	load_local "$1"
	[ -n "$LOCAL_EXIT" ] && [ -n "$CHECKED_IP" ] && [ "$LOCAL_EXIT" != "$CHECKED_IP" ] && differs=true
	[ "$differs" = true ] && exit=$(mask_ip "$LOCAL_EXIT")
	while IFS= read -r row; do
		[ -z "$row" ] && continue
		split_result "$row"
		case $KEY in
		port25) port=$STATUS ;;
		mail)
			for entry in $STATUS $REGION; do key=${entry%%:*} status=${entry#*:}; mail="$mail,\"$key\":\"$status\""; done ;;
		*)
			# Unknown alpha-3 codes can be displayed locally, but are not a report country code.
			case $REGION in [A-Z][A-Z] | '') ;; *) REGION='' ;; esac
			out="$out,\"$KEY\":{\"status\":\"$STATUS\",\"region\":\"$REGION\"}" ;;
		esac
	done <<<"$LOCAL_RESULTS"
	printf '{"family":%s,"platforms":{%s},"port25":"%s","mail":{%s},"exitDiffers":%s,"exitIp":"%s"}' "$1" "${out#,}" "$port" "${mail#,}" "$differs" "$exit"
}

# The report link and the CLI page link share one label column.
footer_width() {
	local a b
	a=$(width "$(l reportLink)"); b=$(width "$(t cli_page)")
	[ "$a" -ge "$b" ] || a=$b
	printf '%s' $((a + 2))
}

create_report() {
	local family tokens='' checks='' token response code body re url error field reason
	for family in $RESULTS; do
		F=$family; token=$(v reportToken)
		[ -z "$token" ] && { detail "$(t report)" "$(t report_missing)" "$(footer_width)"; return; }
		tokens="$tokens,\"$token\""
		checks="$checks,$(report_local_json "$family")"
	done
	[ -z "$tokens" ] && { detail "$(t report)" "$(t report_missing)" "$(footer_width)"; return; }
	family=${RESULTS# }; family=${family%% *}
	body="{\"schema\":\"cli-report/2\",\"clientVersion\":\"$VERSION\",\"locale\":\"$LANG_UI\",\"reportTokens\":[${tokens#,}],\"local\":[${checks#,}]}"
	response=$(curl "-$family" -sS --connect-timeout 8 --max-time 15 -H 'X-IPLense-CLI: 1' -H 'Content-Type: application/json' \
		-A "IPLense-CLI/$VERSION" -X POST --data "$body" -w '\n%{http_code}' "$BASE/cli/v1/report" 2>/dev/null)
	code=${response##*$'\n'}
	body=$(strip_controls "${response%$'\n'*}")
	re='"url"[[:space:]]*:[[:space:]]*"([^"]*)"'
	if [ "$code" = 200 ] && [[ $body =~ $re ]]; then
		url=${BASH_REMATCH[1]}
		url=${url//\\\//\/}
		local lw line
		lw=$(footer_width)
		line="  $(cell "$(l reportLink)" "$lw" dim)$url $(t retention)"
		# Measure the line without its colour codes.
		if [ "$(width "  $(cell "$(l reportLink)" "$lw" '')$url $(t retention)")" -le "$COLS" ]; then printf '%s\n' "$line"
		else
			detail "$(l reportLink)" "$url" "$lw"
			printf '  %*s%s\n' "$lw" '' "$(t retention)"
		fi
		return
	fi
	re='"error"[[:space:]]*:[[:space:]]*"([a-z_]+)"'; error=''
	[[ $body =~ $re ]] && error=${BASH_REMATCH[1]}
	case $error in
	rate_limited) reason=$(l reportRateLimited) ;;
	report_disabled) reason=$(l reportDisabled) ;;
	report_token_expired) reason=$(l reportTokenExpired) ;;
	report_token_mismatch) reason=$(t report_mismatch) ;;
	invalid_field)
		re='"field"[[:space:]]*:[[:space:]]*"([A-Za-z0-9_.-]+)"'; field='body'
		[[ $body =~ $re ]] && field=${BASH_REMATCH[1]}
		reason=$(tf report_invalid "$field") ;;
	header_required) reason=$(t header_required) ;;
	*) reason=$(l reportNetworkError) ;;
	esac
	[ -z "$reason" ] && reason=$(tf server_error "$code")
	detail "$(t report)" "$reason" "$(footer_width)"
}

main() {
	local opt
	case ${LC_ALL:-${LC_MESSAGES:-${LANG:-}}} in zh* | ZH*) LANG_UI=zh ;; esac
	while getopts '46l:jfpo:hV' opt; do
		case $opt in
		4) FAMILIES=4 ;;
		6) FAMILIES=6 ;;
		l) case $OPTARG in zh* | cn) LANG_UI=zh ;; *) LANG_UI=en ;; esac ;;
		j) JSON=1 ;;
		f) FULL=1 ;;
		p) PRIVATE=1 ;;
		o) OUT=$OPTARG ;;
		h) usage; return 0 ;;
		V) printf 'IPLense %s %s\n' "$(t client_name)" "$VERSION"; return 0 ;;
		*) printf '%s\n' "$(t bad_option)" >&2; return 2 ;;
		esac
	done
	if ! command -v curl >/dev/null 2>&1; then
		printf '%s\n' "$(t need_curl)" >&2
		return 1
	fi

	COLOR=0
	if on_terminal && [ -z "${NO_COLOR-}" ] && [ "${TERM-}" != dumb ]; then COLOR=1; fi
	COLS=80
	if on_terminal; then
		COLS=${COLUMNS:-$(tput cols 2>/dev/null || printf 80)}
		case $COLS in '' | *[!0-9]*) COLS=80 ;; esac
	elif [ -n "${COLUMNS-}" ]; then
		case $COLUMNS in *[!0-9]* | '') ;; *) COLS=$COLUMNS ;; esac
	fi
	[ "$COLS" -lt 72 ] && COLS=72
	[ "$COLS" -gt 120 ] && COLS=120
	case ${LC_ALL:-${LC_CTYPE:-${LANG:-}}} in
	*UTF-8* | *utf8* | *UTF8* | *utf-8*)
		MARK_HIT='●' MARK_CLEAR='·' MARK_NONE='–' SEP=' · '
		BOX_H='─' BAR='━' BAR_AT='┃'
		;;
	*)
		MARK_HIT='x' MARK_CLEAR='.' MARK_NONE='-' SEP=' / '
		BOX_H='-' BAR='=' BAR_AT='|'
		;;
	esac

	local family format ok=0 reached=0 json_parts='' re http
	LOCAL_FAMILY=
	LOCAL_FAMILIES=
	CHECKED_IP=
	RESULTS=
	format=kv
	[ "$JSON" = 1 ] && format=json
	for family in $FAMILIES; do
		progress "$(tf checking "$family")"
		fetch "$family" "$format"
		clear_progress
		[ -n "$STATUS" ] && reached=1
		# Local checks go over the first family that reached the server (IPv4 on a dual-stack machine).
		[ -n "$STATUS" ] && LOCAL_FAMILIES="$LOCAL_FAMILIES $family"
		http=$STATUS
		if [ "$JSON" = 1 ]; then
			re='"aiRegions":\{"version":"[^"]*","chatgpt":"([A-Z,]*)","claude":"([A-Z,]*)"\}'
			if [ -z "${AI_JSON_LISTS-}" ] && [[ $BODY =~ $re ]]; then
				AI_JSON_LISTS="chatgpt=${BASH_REMATCH[1]}"$'\n'"claude=${BASH_REMATCH[2]}"
			fi
			re='"ip"[[:space:]]*:[[:space:]]*"([0-9A-Fa-f.:]+)"'
			[[ $BODY =~ $re ]] && printf -v "CHECKED_IP_$family" '%s' "${BASH_REMATCH[1]}"
			if [ "$FULL" = 1 ] && [ "$http" = 200 ] && [[ $BODY != *'"error"'* ]]; then
				local ptr ref="CHECKED_IP_$family"
				ptr=$(strip_controls "$(reverse_dns "${!ref}")")
				ptr=${ptr//\\/\\\\}; ptr=${ptr//\"/\\\"}; ptr=${ptr//$'\n'/\\n}
				BODY="${BODY%\}},\"reverseDns\":\"$ptr\"}"
			fi
			case $BODY in *'"family_mismatch"'*) drop_local_family "$family" ;; esac
			case $BODY in
			'{'*) json_parts="$json_parts,\"ipv$family\":$(private_json "$BODY")" ;;
			*) json_parts="$json_parts,\"ipv$family\":{\"error\":\"unreachable\"}" ;;
			esac
			[ "$http" = 200 ] && ok=1
			continue
		fi
		# A family without a result keeps its reason in FAIL_<family> and the reason's colour in FAIL_STYLE_<family>.
		printf -v "FAIL_STYLE_$family" '%s' neu
		if [ -z "$STATUS" ]; then
			printf -v "FAIL_$family" '%s' "$(t no_conn)"
			printf -v "FAIL_STYLE_$family" '%s' dim
			continue
		fi
		parse_kv "$family" "$BODY"
		F=$family
		if [ "$(v schema)" != "$SCHEMA" ]; then
			printf -v "FAIL_$family" '%s' "$(t schema)"
		elif [ "$(v error)" = family_mismatch ]; then
			drop_local_family "$family"
			# A proxy carried this family's request out over the other one; the server answers without counting it. The address
			# it arrived from is named unless the header already shows it (the other family's own result).
			if [ -n "$CHECKED_IP" ] && [ "$(v ip)" = "$CHECKED_IP" ]; then
				printf -v "FAIL_$family" '%s' "$(tf other_family_shown "$family" "$(v arrivedFamily)")"
			else
				printf -v "FAIL_$family" '%s' "$(tf other_family "$family" "$(v arrivedFamily)" "$(display_ip "$(v ip)")")"
			fi
			printf -v "FAIL_STYLE_$family" '%s' dim
		elif [ "$STATUS" != 200 ]; then
			printf -v "FAIL_$family" '%s' "$(failure "$STATUS")"
		else
			RESULTS="$RESULTS $family"
			CHECKED_IP=$(v ip)
			printf -v "CHECKED_IP_$family" '%s' "$CHECKED_IP"
			if [ "$FULL" = 1 ]; then printf -v "K${family}_reverseDns" '%s' "$(strip_controls "$(reverse_dns "$CHECKED_IP")")"; fi
			ok=1
		fi
	done

	if [ "$JSON" = 1 ] && [ -n "$LOCAL_FAMILIES" ]; then
		family=${LOCAL_FAMILIES# }; LOCAL_FAMILIES=${family%% *}
	fi
	for family in $LOCAL_FAMILIES; do
		LOCAL_FAMILY=$family
		run_local
		printf -v "LOCAL_RESULTS_$family" '%s' "$LOCAL_RESULTS"
		printf -v "LOCAL_EXIT_$family" '%s' "$LOCAL_EXIT"
	done
	local output
	if [ "$JSON" = 1 ]; then
		# Preserve the JSON client's existing local object (the first reachable family).
		if [ -n "$LOCAL_FAMILIES" ]; then
			family=${LOCAL_FAMILIES# }; family=${family%% *}
			load_local "$family"
			json_parts="$json_parts,\"local\":$(local_json)"
		fi
		output="{\"cli\":\"$VERSION\"$json_parts}"
	else
		REPORT_LINES=''
		[ "$PRIVATE" = 0 ] && REPORT_LINES=$(create_report)
		output=$(render_report)
	fi
	# Cells are padded to their width; the last one leaves trailing spaces behind.
	output=$(printf '%s\n' "$output" | sed 's/ *$//')
	printf '%s\n' "$output"
	if [ "$JSON" = 0 ]; then
		local footer
		footer=$(printf '  %s%s' "$(cell "$(t cli_page)" "$(footer_width)" dim)" "$BASE/$LANG_UI/cli")
		printf '%s\n' "$footer"
		output="$output"$'\n'"$footer"
	fi
	if [ -n "$OUT" ]; then
		# The saved copy carries no colour codes (nor the spaces a label leaves at the end of a line).
		local LC_ALL=C plain=$output
		plain=$(printf '%s' "$plain" | sed -e $'s/\033\\[[0-9;]*m//g' -e 's/ *$//')
		if printf '%s\n' "$plain" >"$OUT"; then
			printf '%s\n' "$(tf saved "$OUT")" >&2
		else
			printf '%s\n' "$(tf write_failed "$OUT")" >&2
			return 1
		fi
	fi
	if [ "$ok" = 0 ]; then
		[ "$reached" = 0 ] && printf '%s\n' "$(t all_failed)" >&2
		return 1
	fi
	return 0
}

main "$@"
