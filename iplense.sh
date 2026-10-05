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
# public mail server; those see the connection IP. Nothing else about this machine is sent, and results stay here.
# It needs bash and curl, no root, installs nothing, and writes no file except the one named with -o.

VERSION=1.1.0
BASE=https://iplense.cc
SCHEMA=cli-self/1

LANG_UI=en
FAMILIES='4 6'
JSON=0
OUT=

# ---------------------------------------------------------------------------------------------------------------------
# Text

t() {
	local zh en
	case $1 in
	title) zh='IPLense 本机 IP 体检'; en='IPLense self-check' ;;
	checking) zh='正在检测 IPv%s…'; en='Checking IPv%s…' ;;
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
	report) zh='完整结果'; en='Full result' ;;
	cli_page) zh='关于 CLI'; en='About the CLI' ;;
	platforms) zh='AI 与流媒体'; en='AI and streaming' ;;
	local_progress) zh='本地检测 %s/%s…'; en='Local checks %s/%s…' ;;
	local_exit) zh='出口 %s'; en='exit %s' ;;
	local_exit_note) zh='与上方检测的 IP 不同，平台看到的是这个出口'; en='Differs from the IP checked above; the platforms see this exit' ;;
	available) zh='可用'; en='Available' ;;
	unavailable) zh='不可用'; en='Unavailable' ;;
	failed) zh='检测失败'; en='Check failed' ;;
	originals_only) zh='仅自制内容'; en='Originals only' ;;
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
			'IPLense 自检：检测本机出口 IP 的归属、类型与多源风险，以及 AI 平台、流媒体与 25 端口。' \
			'' \
			'用法：bash <(curl -sL https://iplense.cc/cli) [选项]' \
			'  -4         只检测 IPv4' \
			'  -6         只检测 IPv6' \
			'  -l zh|en   输出语言（cn 同 zh；默认按 LANG）' \
			'  -j         输出 JSON' \
			'  -o 文件    同时把输出保存到文件' \
			'  -h         显示本帮助' \
			'  -V         显示版本' \
			'' \
			'向 iplense.cc 每个协议族发一次请求，服务器只得到连接 IP。' \
			'本地检测向各平台发 1–3 次请求，Disney+ 会注册一个匿名设备；结果只显示在本机。' \
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
			'  -o FILE    Also save the output to FILE' \
			'  -h         Show this help' \
			'  -V         Show the version' \
			'' \
			'Sends one request per IP family to iplense.cc; the server sees only the connection IP.' \
			'Local checks send 1-3 requests to each platform; Disney+ registers an anonymous device. Results stay here.' \
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

# Cuts text to at most $2 columns, ending with an ellipsis when it was longer.
clip() {
	local s=$1 max=$2 w out='' rest ch
	w=$(width "$s")
	if [ "$w" -le "$max" ]; then printf '%s' "$s"; return; fi
	local LC_ALL=C
	rest=$s
	while [ -n "$rest" ]; do
		ch=${rest:0:1}
		rest=${rest:1}
		while [ -n "$rest" ]; do
			case ${rest:0:1} in [$'\200'-$'\277']) ch=$ch${rest:0:1}; rest=${rest:1} ;; *) break ;; esac
		done
		if [ $(($(width "$out$ch") + $(width "$ELLIPSIS"))) -gt "$max" ]; then break; fi
		out=$out$ch
	done
	printf '%s%s' "$out" "$ELLIPSIS"
}

# One cell: text padded to $2 columns (right-aligned when $4 is "r"), coloured with style $3. A left-aligned cell keeps at
# least GAP (default 1) blank columns before the next one, clipping its text when needed.
cell() {
	local text w pad room=$2
	[ "${4-}" != r ] && room=$(($2 - ${GAP:-1}))
	text=$(clip "$1" "$room")
	w=$(width "$text")
	pad=$(($2 - w))
	[ "$pad" -lt 0 ] && pad=0
	if [ "${4-}" = r ]; then printf '%*s' "$pad" ''; fi
	paint "$3" "$text"
	if [ "${4-}" != r ]; then printf '%*s' "$pad" ''; fi
}

# Colours, each the nearest of the 16 basic ANSI colours to the website's own (README "Colours"): pos green, neu yellow,
# neg red, none bright black (unknown, failed, not provided); a style starting with b is a label on that background.
paint() {
	if [ "$COLOR" = 1 ] && [ -n "$1" ] && [ -n "$2" ]; then
		local code
		case $1 in
		pos) code=32 ;; neu) code=33 ;; neg) code=31 ;; none) code=90 ;; dim) code=2 ;; bold) code=1 ;; head) code='1;94' ;;
		bpos) code='97;42' ;; bneu) code='30;43' ;; bneg) code='97;41' ;; bnone) code='97;100' ;; *) code=0 ;;
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

# Columns a cell takes: a label is two wider than its text.
cell_width() {
	case $2 in b*) printf '%s' $(($(width "$1") + 2)) ;; *) width "$1" ;; esac
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
	case $1 in ISP) printf bpos ;; IDC | Error) printf bneg ;; *) printf bneu ;; esac
}

# A Quick type (ASN and operator) as the web result card colours it, where Unknown is grey.
quick_type_style() {
	case $1 in ISP) printf bpos ;; IDC | Error) printf bneg ;; Business) printf bneu ;; *) printf bnone ;; esac
}

# A Professional type in the site's words.
type_text() {
	case $1 in ISP | IDC | Business | Unknown | Error) l "proType_$1" ;; '') printf '' ;; *) l proType_Unknown ;; esac
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

# A section heading, numbered in the order shown ("一、" in Chinese, "1." in English); $2 is added after it as given.
SECTION=0
section() {
	local n
	SECTION=$((SECTION + 1))
	if [ "$LANG_UI" = zh ]; then
		case $SECTION in 1) n='一、' ;; 2) n='二、' ;; 3) n='三、' ;; 4) n='四、' ;; 5) n='五、' ;; *) n='六、' ;; esac
	else
		n="$SECTION. "
	fi
	printf '\n%s%s\n' "$(paint head "$n$1")" "${2-}"
}

# The report header: a bordered title, then the IPs checked, the version and when the result was made.
render_header() {
	local inner=$((COLS - 2)) title tw left ips='' family meta made=''
	title=$(t title)
	tw=$(width "$title")
	left=$(((inner - tw) / 2))
	printf '%s\n' "$(paint head "$BOX_TL$(repeat "$BOX_H" "$inner")$BOX_TR")"
	printf '%s%*s%s%*s%s\n' "$(paint head "$BOX_V")" "$left" '' "$(paint bold "$title")" $((inner - tw - left)) '' "$(paint head "$BOX_V")"
	printf '%s\n' "$(paint head "$BOX_BL$(repeat "$BOX_H" "$inner")$BOX_BR")"
	for family in $RESULTS; do
		F=$family
		ips=${ips:+$ips$SEP}$(v ip)
		[ -z "$made" ] && made=$(v generatedAt)
	done
	case $made in
	[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]*) made="${made:0:10} ${made:11:5} UTC" ;;
	*) made='' ;;
	esac
	meta=$(joined "CLI $VERSION" "$made")
	if [ -z "$ips" ]; then
		printf '  %s\n' "$(paint dim "$meta")"
	elif [ $(($(width "$ips$SEP$meta") + 2)) -le "$COLS" ]; then
		printf '  %s%s\n' "$(paint bold "$ips")" "$(paint dim "$SEP$meta")"
	else
		printf '  %s\n  %s\n' "$(paint bold "$ips")" "$(paint dim "$meta")"
	fi
}

# A family that has no result: its reason on one line.
render_failure() {
	local family=$1 style text
	text=FAIL_$family
	style=FAIL_STYLE_$family
	printf '  %s  %s\n' "$(paint head "IPv$family")" "$(paint "${!style}" "${!text}")"
}

# Section one for a family: ownership, location, registration and the two property labels, as the web result card.
render_basic() {
	local lw=3 key name company type nature property line nature_style property_style
	F=$1
	for key in operator location registration ipProperty; do lw=$(max "$lw" "$(width "$(l "$key")")"); done
	lw=$((lw + 2))
	name=$(v quick.asn.name)
	type=$(v quick.asn.type)
	line=$(joined "AS$(v quick.asn.number)" "$name")
	[ -n "$type" ] && line="$line  $(label "$type" 0 "$(quick_type_style "$type")")"
	printf '  %s%s\n' "$(cell ASN "$lw" dim)" "$line"
	company=$(v quick.company.name)
	type=$(v quick.company.type)
	if [ -n "$company" ] && [ "$company" != "$name" ]; then
		line=$company
		[ -n "$type" ] && line="$line  $(label "$type" 0 "$(quick_type_style "$type")")"
		printf '  %s%s\n' "$(cell "$(l operator)" "$lw" dim)" "$line"
	fi
	printf '  %s%s\n' "$(cell "$(l location)" "$lw" dim)" "$(joined "$(v quick.location.country)" "$(v quick.location.region)" "$(v quick.location.city)")"
	[ -n "$(v quick.registrationCountryCode)" ] && printf '  %s%s\n' "$(cell "$(l registration)" "$lw" dim)" "$(v quick.registrationCountryCode)"
	nature=$(v quick.ipNature)
	property=$(v quick.ipProperty)
	case $nature in Native) nature_style=bpos ;; Broadcast) nature_style=bneu ;; Unknown | '') nature_style=bnone ;; *) nature_style=bneg ;; esac
	case $property in Residential | HomeBroadband) property_style=bpos ;; Unknown | '') property_style=bnone ;; *) property_style=bneg ;; esac
	printf '  %s%s %s\n' "$(cell "$(l ipProperty)" "$lw" dim)" "$(label "$(l "nature_${nature:-Unknown}")" 0 "$nature_style")" \
		"$(label "$(l "property_${property:-Unknown}")" 0 "$property_style")"
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

# A provider none of whose modules answered, named once with the reason (in the first section that lists it), its name in
# a column $3 wide.
render_failed_provider() {
	if [ "$2" = QuotaUnavailable ]; then
		printf '  %s%s\n' "$(cell "$(brand "$1")" "$3" bold)" "$(paint neu "$(l rowQuota)")"
	else
		printf '  %s%s\n' "$(cell "$(brand "$1")" "$3" bold)" "$(paint neg "$(l rowError)")"
	fi
}

# A module that did not answer, as text and style in MT and MS.
module_text() {
	case $1 in
	QuotaUnavailable) MT=$(l quotaUnavailable) MS=neu ;;
	*) MT=$(l error) MS=neg ;;
	esac
}

# Sources side by side on one line: a column per source (SB_NAMES), a row per field (SB_HEAD), the cells of field j in the
# arrays SB_Tj (text) and SB_Sj (style). Returns 1, printing nothing, when they do not fit the width.
side_by_side() {
	local np=${#SB_NAMES[@]} nf=${#SB_HEAD[@]} lw i j w ref sref used widths=()
	lw=$(width "$(l colSource)")
	j=0
	while [ "$j" -lt "$nf" ]; do lw=$(max "$lw" "$(width "${SB_HEAD[$j]}")"); j=$((j + 1)); done
	lw=$((lw + 2))
	used=$((2 + lw))
	i=0
	while [ "$i" -lt "$np" ]; do
		w=$(width "${SB_NAMES[$i]}")
		j=0
		while [ "$j" -lt "$nf" ]; do
			ref="SB_T${j}[$i]"
			sref="SB_S${j}[$i]"
			w=$(max "$w" "$(cell_width "${!ref}" "${!sref}")")
			j=$((j + 1))
		done
		widths[i]=$((w + 2))
		used=$((used + w + 2))
		i=$((i + 1))
	done
	[ "$used" -le "$COLS" ] || return 1
	printf '  %s' "$(cell "$(l colSource)" "$lw" dim)"
	i=0
	while [ "$i" -lt "$np" ]; do printf '%s' "$(cell "${SB_NAMES[$i]}" "${widths[$i]}" bold)"; i=$((i + 1)); done
	printf '\n'
	j=0
	while [ "$j" -lt "$nf" ]; do
		printf '  %s' "$(cell "${SB_HEAD[$j]}" "$lw" dim)"
		i=0
		while [ "$i" -lt "$np" ]; do
			ref="SB_T${j}[$i]"
			sref="SB_S${j}[$i]"
			printf '%s' "$(GAP=2 any_cell "${!ref}" "${widths[$i]}" "${!sref}")"
			i=$((i + 1))
		done
		printf '\n'
		j=$((j + 1))
	done
}

# Section two for a family: a row per source with its location and its usage and company types as labels, at every width.
render_types() {
	local list provider li ti n=0 state name_w loc_w uw cw over key failed='' usage company
	F=$1
	SB_NAMES=() SB_T0=() SB_S0=() SB_T1=() SB_S1=() SB_T2=() SB_S2=()
	IFS=$'\n' read -r -d '' -a list < <(providers)
	for provider in "${list[@]}"; do
		li=$(index_of locations "$provider")
		ti=$(index_of types "$provider")
		[ -z "$li$ti" ] && continue
		state=$(provider_state "$provider")
		if [ "$state" != Success ]; then
			failed=$failed$provider$'\t'$state$'\n'
			name_w=$(max "${name_w:-0}" "$(width "$(brand "$provider")")")
			continue
		fi
		SB_NAMES[n]=$(brand "$provider")
		name_w=$(max "${name_w:-0}" "$(width "${SB_NAMES[n]}")")
		if [ -z "$li" ]; then
			SB_T0[n]=$MARK_NONE SB_S0[n]=none
		elif [ "$(v "professional.locations.$li.state")" = Success ]; then
			SB_T0[n]=$(joined "$(v "professional.locations.$li.countryCode")" "$(v "professional.locations.$li.city")") SB_S0[n]=''
			[ -z "${SB_T0[n]}" ] && SB_T0[n]=$MARK_NONE SB_S0[n]=none
		else
			module_text "$(v "professional.locations.$li.state")"
			SB_T0[n]=$MT SB_S0[n]=$MS
		fi
		# A module that did not answer is said once, in the usage cell.
		if [ -z "$ti" ]; then
			SB_T1[n]=" $MARK_NONE" SB_S1[n]=none SB_T2[n]=" $MARK_NONE" SB_S2[n]=none
		elif [ "$(row_type_state "$ti")" = Success ]; then
			usage=$(v "professional.types.$ti.usageType")
			company=$(v "professional.types.$ti.companyType")
			SB_T1[n]=$(type_text "$usage") SB_S1[n]=$(type_style "$usage")
			if [ -n "$company" ]; then SB_T2[n]=$(type_text "$company") SB_S2[n]=$(type_style "$company"); else SB_T2[n]=" $MARK_NONE" SB_S2[n]=none; fi
		else
			module_text "$(row_type_state "$ti")"
			SB_T1[n]=$MT SB_S1[n]=$MS SB_T2[n]='' SB_S2[n]=''
		fi
		n=$((n + 1))
	done
	# Each column is as wide as its widest content and two spaces; the type headings start where the label text does.
	name_w=$(($(max "${name_w:-0}" "$(width "$(l colSource)")") + 2))
	if [ "$n" -gt 0 ]; then
		loc_w=$(width "$(l location)")
		uw=$(($(width "$(l usageType)") + 1))
		cw=$(($(width "$(l companyType)") + 1))
		key=0
		while [ "$key" -lt "$n" ]; do
			loc_w=$(max "$loc_w" "$(width "${SB_T0[$key]}")")
			case ${SB_S1[$key]} in
			b* | none)
				uw=$(max "$uw" "$(cell_width "${SB_T1[$key]}" "${SB_S1[$key]}")")
				cw=$(max "$cw" "$(cell_width "${SB_T2[$key]}" "${SB_S2[$key]}")")
				;;
			esac
			key=$((key + 1))
		done
		loc_w=$((loc_w + 2)) uw=$((uw + 2)) cw=$((cw + 2))
		# Within the terminal: a location too long for the room left is cut.
		over=$((2 + name_w + loc_w + uw + cw - COLS))
		[ "$over" -gt 0 ] && loc_w=$((loc_w - over))
		printf '  %s%s%s%s\n' "$(cell "$(l colSource)" "$name_w" dim)" "$(cell "$(l location)" "$loc_w" dim)" "$(cell " $(l usageType)" "$uw" dim)" \
			"$(cell " $(l companyType)" "$cw" dim)"
		key=0
		while [ "$key" -lt "$n" ]; do
			printf '  %s%s' "$(cell "${SB_NAMES[$key]}" "$name_w" bold)" "$(GAP=2 any_cell "${SB_T0[$key]}" "$loc_w" "${SB_S0[$key]}")"
			case ${SB_S1[$key]} in
			b* | none) printf '%s%s\n' "$(any_cell "${SB_T1[$key]}" "$uw" "${SB_S1[$key]}")" "$(any_cell "${SB_T2[$key]}" "$cw" "${SB_S2[$key]}")" ;;
			*) printf '%s\n' "$(paint "${SB_S1[$key]}" "${SB_T1[$key]}")" ;;
			esac
			key=$((key + 1))
		done
	fi
	printf '%s' "$failed" | while IFS=$'\t' read -r provider state; do render_failed_provider "$provider" "$state" "$name_w"; done
}

# Section three for a family: the IPLense score and purity risk value on their scales, then each source's risk value
# coloured by the same thresholds: side by side when they fit on one line, else a row per source.
render_risk() {
	local lw vw score purity tone level list provider li ti ri n=0 state value key
	F=$1
	score=$(v quick.score)
	purity=$(v quick.purity.value)
	lw=$(max 15 "$(width "IPLense $(l score)")")
	lw=$(max "$lw" "$(width "$(l purity) $(l purityRisk)")")
	lw=$((lw + 2))
	vw=$(max 6 "$(width "$(l colRiskValue)")")
	if [ -n "$score" ]; then
		printf '  %s%s  %s\n' "$(cell "IPLense $(l score)" "$lw" dim)" "$(cell "$score" "$vw" "$(score_tone "$score")" r)" "$(scale "$score" score)"
	fi
	if [ -n "$purity" ]; then
		case $(v quick.purity.state) in good) tone=pos level=low ;; average) tone=neu level=medium ;; *) tone=neg level=high ;; esac
		printf '  %s%s  %s  %s\n' "$(cell "$(l purity) $(l purityRisk)" "$lw" dim)" "$(cell "$purity/100" "$vw" "$tone" r)" \
			"$(scale "$purity" risk)" "$(paint "$tone" "$(l "level_$level")")"
	fi

	SB_NAMES=() SB_T0=() SB_S0=()
	local failed=''
	IFS=$'\n' read -r -d '' -a list < <(providers)
	for provider in "${list[@]}"; do
		ri=$(index_of riskSources "$provider")
		[ -z "$ri" ] && continue
		state=$(provider_state "$provider")
		if [ "$state" != Success ]; then
			# Named in section two when it has a location or type there.
			li=$(index_of locations "$provider")
			ti=$(index_of types "$provider")
			[ -z "$li$ti" ] && failed=$failed$provider$'\t'$state$'\n'
			continue
		fi
		SB_NAMES[n]=$(brand "$provider")
		if [ "$(row_risk_state "$ri")" = Success ]; then
			value=$(v "professional.riskSources.$ri.score.value")
			level=$(v "professional.riskSources.$ri.score.level")
			if [ -n "$value" ]; then
				value=${value%%.*}
				SB_T0[n]=$value SB_S0[n]=$(risk_tone "$value")
			elif [ -n "$level" ]; then
				level=$(printf '%s' "$level" | tr '[:upper:]' '[:lower:]')
				case $level in low) tone=pos ;; medium) tone=neu ;; *) tone=neg ;; esac
				SB_T0[n]=$(l "level_$level") SB_S0[n]=$tone
			else
				SB_T0[n]=$MARK_NONE SB_S0[n]=none
			fi
		else
			module_text "$(row_risk_state "$ri")"
			SB_T0[n]=$MT SB_S0[n]=$MS
		fi
		n=$((n + 1))
	done
	[ "$n" -gt 0 ] || [ -n "$failed" ] || return 0
	printf '\n'
	SB_HEAD=("$(l colRiskValue)")
	if [ "$n" -gt 0 ] && side_by_side; then
		:
	elif [ "$n" -gt 0 ]; then
		printf '  %s%s\n' "$(cell "$(l colSource)" "$lw" dim)" "$(cell "$(l colRiskValue)" "$vw" dim r)"
		key=0
		while [ "$key" -lt "$n" ]; do
			# A module that did not answer says so in full after the name.
			case ${SB_S0[$key]} in
			neu | neg) [ "$(width "${SB_T0[$key]}")" -gt "$vw" ] && value=$(paint "${SB_S0[$key]}" "${SB_T0[$key]}") || value=$(cell "${SB_T0[$key]}" "$vw" "${SB_S0[$key]}" r) ;;
			*) value=$(cell "${SB_T0[$key]}" "$vw" "${SB_S0[$key]}" r) ;;
			esac
			printf '  %s%s\n' "$(cell "${SB_NAMES[$key]}" "$lw" bold)" "$value"
			key=$((key + 1))
		done
	fi
	printf '%s' "$failed" | while IFS=$'\t' read -r provider state; do render_failed_provider "$provider" "$state" "$lw"; done
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

# Section four for a family: the matrix, its marks red (detected), green (not detected) and grey (not provided).
render_factors() {
	local name_w provider ri column mark list names=() rows=() n signals widths=() c
	F=$1
	IFS=$'\n' read -r -d '' -a list < <(providers)
	for provider in "${list[@]}"; do
		ri=$(index_of riskSources "$provider")
		[ -z "$ri" ] && continue
		[ "$(row_risk_state "$ri")" = Success ] || continue
		[ -n "$(v "professional.riskSources.$ri.signals.0.canonicalKey")" ] || continue
		names[${#names[@]}]=$provider
		rows[${#rows[@]}]=$ri
	done
	[ "${#rows[@]}" -eq 0 ] && return
	# Each column is as wide as its heading or widest name and two spaces (a mark is one column).
	name_w=$(width "$(l colSource)")
	n=0
	while [ "$n" -lt "${#names[@]}" ]; do name_w=$(max "$name_w" "$(width "$(brand "${names[$n]}")")"); n=$((n + 1)); done
	name_w=$((name_w + 2))
	printf '  %s' "$(cell "$(l colSource)" "$name_w" dim)"
	c=0
	for column in $COLUMNS_RISK; do
		widths[c]=$(($(width "$(l "column_${column%%:*}")") + 2))
		printf '%s' "$(cell "$(l "column_${column%%:*}")" "${widths[c]}" dim)"
		c=$((c + 1))
	done
	printf '\n'
	n=0
	while [ "$n" -lt "${#rows[@]}" ]; do
		printf '  %s' "$(cell "$(brand "${names[$n]}")" "$name_w" bold)"
		signals=$(signal_states "${rows[$n]}")
		c=0
		for column in $COLUMNS_RISK; do
			mark=$(risk_mark "$signals" "${column#*:}")
			case $mark in
			detected) printf '%s' "$(cell "$MARK_HIT" "${widths[c]}" neg)" ;;
			clear) printf '%s' "$(cell "$MARK_CLEAR" "${widths[c]}" pos)" ;;
			*) printf '%s' "$(cell "$MARK_NONE" "${widths[c]}" none)" ;;
			esac
			c=$((c + 1))
		done
		printf '\n'
		n=$((n + 1))
	done
}

# The matrix's legend, once under every family's matrix.
render_legend() {
	printf '  %s %s  %s %s  %s %s\n' "$(paint neg "$MARK_HIT")" "$(l cell_detected)" "$(paint pos "$MARK_CLEAR")" "$(l cell_clear)" \
		"$(paint none "$MARK_NONE")" "$(l cell_none)"
}

# The whole report. Sections one to four need a result from at least one family; five and six need the local checks.
render_report() {
	local family count=0 block blocks out
	for family in $RESULTS; do count=$((count + 1)); done
	render_header
	if [ "$count" -gt 0 ]; then
		F=${RESULTS# }
		F=${F%% *}
		section "$(l sectionBasic)"
		for family in $FAMILIES; do
			case " $RESULTS " in
			*" $family "*)
				if [ "$FAMILIES" != "$family" ]; then
					[ "$family" != "${FAMILIES%% *}" ] && printf '\n'
					printf '  %s\n' "$(paint bold "IPv$family")"
				fi
				render_basic "$family"
				;;
			*)
				[ "$family" != "${FAMILIES%% *}" ] && printf '\n'
				render_failure "$family"
				;;
			esac
		done
		for block in types risk factors; do
			blocks=''
			for family in $RESULTS; do
				F=$family
				out=$("render_$block" "$family")
				[ -z "$out" ] && continue
				[ "$count" -gt 1 ] && out="  $(paint bold "IPv$family")"$'\n'$out
				blocks=${blocks:+$blocks$'\n\n'}$out
			done
			[ -z "$blocks" ] && continue
			F=${RESULTS# }
			F=${F%% *}
			case $block in types) section "$(l sectionTypes)" ;; risk) section "$(l sectionRisk)" ;; factors) section "$(l statRiskHits)" ;; esac
			printf '%s\n' "$blocks"
			[ "$block" = factors ] && render_legend
		done
	else
		printf '\n'
		for family in $FAMILIES; do render_failure "$family"; done
	fi
	[ -n "$LOCAL_FAMILY" ] && render_local
	render_footer
}

# A rule, then the full result for each family checked and the CLI page, one line each.
render_footer() {
	local lw family label
	lw=$(max "$(width "$(t report)")" "$(width "$(t cli_page)")")
	lw=$((lw + 2))
	printf '\n%s\n' "$(paint dim "$(repeat "$BOX_H" "$COLS")")"
	label=$(t report)
	for family in $RESULTS; do
		F=$family
		printf '  %s%s\n' "$(cell "$label" "$lw" dim)" "$BASE/$LANG_UI/ip/$(v ip)"
		label=''
	done
	printf '  %s%s\n' "$(cell "$(t cli_page)" "$lw" dim)" "$BASE/$LANG_UI/cli"
}

# ---------------------------------------------------------------------------------------------------------------------
# Local checks: what AI and streaming platforms and a mail server answer this machine. Each reads one to three responses
# and reports only what a response states; anything else is "check failed". Results stay on this machine.
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
LOCAL_CHECKS='chatgpt claude gemini netflix disney youtube tiktok prime reddit port25'

# One request over the local checks' family; sets PAGE (the body) and PAGE_STATUS ("<code> <final URL>", empty on failure).
page() {
	local out
	out=$(curl "-$LOCAL_FAMILY" -sS -L --connect-timeout 8 --max-time 10 -A "$UA_BROWSER" -H 'Accept-Language: en' "$@" \
		-w '\n%{http_code} %{url_effective}' 2>/dev/null)
	local rc=$?
	PAGE_STATUS=${out##*$'\n'}
	PAGE=${out%$'\n'*}
	if [ "$rc" -ne 0 ] || [ "${PAGE_STATUS%% *}" = 000 ]; then PAGE_STATUS=; PAGE=; fi
}

# The first capture of a regular expression in PAGE, or nothing.
match() {
	local re=$1
	if [[ $PAGE =~ $re ]]; then printf '%s' "${BASH_REMATCH[1]}"; fi
}

# A check's answer: "status region", status one of available, unavailable, failed, supported, unsupported, originals_only.
# The AI checks add a second line with the address the platform's trace saw (its ip= field), the exit the platforms see.
check_ai() {
	local platform=$1 host=$2 region list exit answer
	page "https://$host/cdn-cgi/trace"
	exit=$(match $'\nip=([0-9A-Fa-f.:]+)')
	region=$(match $'\nloc=([A-Z]{2})')
	list=$(ai_list "$platform")
	if [ -z "$region" ]; then answer=failed
	elif [ -z "$list" ]; then answer="region $region"
	elif case ",$list," in *",$region,"*) true ;; *) false ;; esac; then answer="supported $region"
	else answer="unsupported $region"; fi
	printf '%s' "$answer"
	[ -n "$exit" ] && printf '\n%s' "$exit"
}

# Gemini (RegionRestrictionCheck): an undocumented page flag and the country Google states; no flag is a failed check.
check_gemini() {
	page https://gemini.google.com
	if [[ $PAGE == *'45631641,null,true'* ]]; then printf 'available %s' "$(alpha2 "$(match ',2,1,200,"([A-Z]{3})"')")"; else printf 'failed'; fi
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
	[ -z "$PAGE_STATUS" ] && { printf 'failed'; return; }
	original=$PAGE_STATUS
	[[ $PAGE == *'Oh no!'* ]] && original=no
	region=$(match '"id":"([A-Z]{2})","countryName"')
	page https://www.netflix.com/title/70143836
	[ -z "$PAGE_STATUS" ] && { printf 'failed'; return; }
	licensed=$PAGE_STATUS
	[[ $PAGE == *'Oh no!'* ]] && licensed=no
	[ -z "$region" ] && region=$(match '"id":"([A-Z]{2})","countryName"')
	if [ "${original%% *}" = 403 ] || { [ "$original" = no ] && [ "$licensed" = no ]; }; then printf 'unavailable'
	elif [ "$licensed" = no ] && [ -n "$region" ]; then printf 'originals_only %s' "$region"
	elif [ "${licensed%% *}" = 200 ] && [ -n "$region" ]; then printf 'available %s' "$region"
	else printf 'failed'; fi
}

# Disney+ (RegionRestrictionCheck, IPQuality): register an anonymous browser device, exchange it for a token, then read the
# session's country. The device description is the projects' generic one; nothing about this machine is sent. Three
# requests at most, no retry; any step that does not answer as expected is a failed check.
check_disney() {
	local assertion refresh region supported
	page https://disney.api.edge.bamgrid.com/devices -X POST -H "authorization: Bearer $DISNEY_WEB_CLIENT_KEY" \
		-H 'content-type: application/json; charset=UTF-8' -d '{"deviceFamily":"browser","applicationRuntime":"chrome","deviceProfile":"windows","attributes":{}}'
	assertion=$(match '"assertion" *: *"([^"]+)"')
	[ -z "$assertion" ] && { printf 'failed'; return; }
	page https://disney.api.edge.bamgrid.com/token -X POST -H "authorization: Bearer $DISNEY_WEB_CLIENT_KEY" \
		-d "grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Atoken-exchange&latitude=0&longitude=0&platform=browser&subject_token=$assertion&subject_token_type=urn%3Abamtech%3Aparams%3Aoauth%3Atoken-type%3Adevice"
	[[ $PAGE == *forbidden-location* ]] && { printf 'unavailable'; return; }
	refresh=$(match '"refresh_token" *: *"([^"]+)"')
	[ -z "$refresh" ] && { printf 'failed'; return; }
	# shellcheck disable=SC2016 # $input is a GraphQL variable, sent as written.
	page https://disney.api.edge.bamgrid.com/graph/v1/device/graphql -X POST -H "authorization: $DISNEY_WEB_CLIENT_KEY" \
		-d '{"query":"mutation refreshToken($input: RefreshTokenInput!) { refreshToken(refreshToken: $input) { activeSession { sessionId } } }","variables":{"input":{"refreshToken":"'"$refresh"'"}}}'
	region=$(match '"countryCode" *: *"([A-Z]{2})"')
	supported=$(match '"inSupportedLocation" *: *(true|false)')
	if [ -n "$region" ] && [ "$supported" = true ]; then printf 'available %s' "$region"
	elif [ -n "$region" ] && [ "$supported" = false ]; then printf 'unavailable %s' "$region"
	else printf 'failed'; fi
}

# YouTube Premium (IPQuality): the page states the region and the offer, or says Premium is not available. A consent page
# (EU) is a failed check: no consent cookie is made up to get past it.
check_youtube() {
	local region
	page https://www.youtube.com/premium
	region=$(match '"contentRegion":"([A-Z]{2})"')
	if [[ $PAGE == *'Premium is not available in your country'* ]]; then printf 'unavailable'
	elif [ -n "$region" ] && [[ $PAGE == *ad-free* ]]; then printf 'available %s' "$region"
	else printf 'failed'; fi
}

# TikTok (IPQuality): the explore page states the visitor's region (the home page answers curl with a challenge).
check_tiktok() {
	local region
	page https://www.tiktok.com/explore --compressed -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
	region=$(match '"region":"([A-Z]{2})"')
	if [ -n "$region" ]; then printf 'available %s' "$region"; else printf 'failed'; fi
}

# Prime Video (IPQuality): the home page states the current territory.
check_prime() {
	local region
	page https://www.primevideo.com
	region=$(match '"currentTerritory":"([A-Z]{2})"')
	if [ -n "$region" ]; then printf 'available %s' "$region"; else printf 'failed'; fi
}

# Reddit (IPQuality): the chat shell answers 200 with the visitor's country, or 403 where Reddit blocks the network.
check_reddit() {
	page https://www.reddit.com/svc/shreddit/reddit-chat
	case ${PAGE_STATUS%% *} in
	200) printf 'available %s' "$(match 'country="([A-Z]{2})"')" ;;
	403) printf 'unavailable' ;;
	*) printf 'failed' ;;
	esac
}

# The mail server's first line over port 25, read within five seconds; QUIT is sent and nothing else. Prints the line;
# returns 1 when the connection fails and 2 when it opens but says nothing.
smtp_greeting() {
	(
		exec 3<>"/dev/tcp/$SMTP_HOST/25" || exit 1
		IFS= read -r -t 5 line <&3 || exit 2
		printf 'QUIT\r\n' >&3
		printf '%s' "$line"
	) 2>/dev/null &
	local pid=$! waited=0
	while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt 50 ]; do
		sleep 0.1
		waited=$((waited + 1))
	done
	kill "$pid" 2>/dev/null
	wait "$pid"
}

check_port25() {
	local greeting status
	greeting=$(smtp_greeting)
	status=$?
	case $status:$greeting in
	0:220*) printf 'available' ;;
	1:*) printf 'unavailable' ;;
	*) printf 'failed' ;;
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
	chatgpt) printf ChatGPT ;; claude) printf Claude ;; gemini) printf Gemini ;; netflix) printf Netflix ;;
	disney) printf 'Disney+' ;; youtube) printf 'YouTube Premium' ;; tiktok) printf TikTok ;; prime) printf 'Prime Video' ;;
	reddit) printf Reddit ;; port25) t port25 ;;
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
		[ -t 2 ] && [ "$JSON" = 0 ] && printf '\r%s' "$(tf local_progress "$n" "$total")" >&2
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
	[ -t 2 ] && [ "$JSON" = 0 ] && printf '\r\033[K' >&2
}

# Splits one LOCAL_RESULTS line into KEY, STATUS and REGION.
split_result() {
	KEY=${1%% *}
	local rest=${1#* }
	STATUS=${rest%% *}
	REGION=
	[ "$rest" != "$STATUS" ] && REGION=${rest#* }
}

render_local() {
	local row style name_w=0 status_w=0 w IFS=$'\n' suffix port25='' differs=0
	set -f
	# The name and status columns fit their longest content (a status label is two wider than its word).
	for row in $LOCAL_RESULTS; do
		split_result "$row"
		[ "$KEY" = port25 ] && continue
		w=$(width "$(local_status "$STATUS")")
		[ "$w" -gt "$status_w" ] && status_w=$w
		name_w=$(max "$name_w" "$(width "$(local_name "$KEY")")")
	done
	status_w=$((status_w + 4))
	name_w=$((name_w + 2))
	# When the platforms leave through another exit than the IP checked above (split routing), the title names it.
	[ -n "$LOCAL_EXIT" ] && [ -n "$CHECKED_IP" ] && [ "$LOCAL_EXIT" != "$CHECKED_IP" ] && differs=1
	suffix="${SEP}IPv$LOCAL_FAMILY"
	[ "$differs" = 1 ] && suffix="$suffix${SEP}$(tf local_exit "$LOCAL_EXIT")"
	section "$(t platforms)" "$(paint dim "$suffix")"
	[ "$differs" = 1 ] && printf '  %s\n' "$(paint dim "$(t local_exit_note)")"
	for row in $LOCAL_RESULTS; do
		split_result "$row"
		style=$(local_style "$STATUS")
		if [ "$KEY" = port25 ]; then
			port25=$(label "$(local_status "$STATUS")" 0 "$style")
		elif [ "$STATUS" = region ]; then
			printf '  %s%s%s\n' "$(cell "$(local_name "$KEY")" "$name_w" bold)" "$(cell " $MARK_NONE" "$status_w" none)" "$REGION"
		else
			printf '  %s%s%s\n' "$(cell "$(local_name "$KEY")" "$name_w" bold)" "$(label "$(local_status "$STATUS")" "$status_w" "$style")" "$REGION"
		fi
	done
	set +f
	section "$(t port25)"
	printf '  %s\n' "$port25"
}

# A local check's label colour, as the website shows platform access: available green, unavailable red, partial amber,
# failed grey.
local_style() {
	case $1 in available | supported) printf bpos ;; unavailable | unsupported) printf bneg ;; originals_only) printf bneu ;; *) printf bnone ;; esac
}

local_status() {
	case $1 in
	supported) l aiSupported ;;
	unsupported) l aiUnsupported ;;
	region) printf '%s' "$MARK_NONE" ;;
	available | unavailable | failed | originals_only) t "$1" ;;
	esac
}

local_json() {
	local row out='' IFS=$'\n'
	set -f
	for row in $LOCAL_RESULTS; do
		split_result "$row"
		out="$out,\"$KEY\":{\"status\":\"$STATUS\",\"region\":\"$REGION\"}"
	done
	set +f
	printf '{"family":%s,"exitIp":"%s"%s}' "$LOCAL_FAMILY" "$LOCAL_EXIT" "$out"
}

# ---------------------------------------------------------------------------------------------------------------------
# Main

# Whether the output goes to a terminal: colour and the terminal's width are used only then.
on_terminal() {
	[ -t 1 ]
}

main() {
	local opt
	case ${LC_ALL:-${LC_MESSAGES:-${LANG:-}}} in zh* | ZH*) LANG_UI=zh ;; esac
	while getopts '46l:jo:hV' opt; do
		case $opt in
		4) FAMILIES=4 ;;
		6) FAMILIES=6 ;;
		l) case $OPTARG in zh* | cn) LANG_UI=zh ;; *) LANG_UI=en ;; esac ;;
		j) JSON=1 ;;
		o) OUT=$OPTARG ;;
		h) usage; return 0 ;;
		V) printf 'IPLense CLI %s\n' "$VERSION"; return 0 ;;
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
		MARK_HIT='●' MARK_CLEAR='·' MARK_NONE='–' SEP=' · ' ELLIPSIS='…'
		BOX_TL='┌' BOX_TR='┐' BOX_BL='└' BOX_BR='┘' BOX_H='─' BOX_V='│' BAR='━' BAR_AT='┃'
		;;
	*)
		MARK_HIT='x' MARK_CLEAR='.' MARK_NONE='-' SEP=' / ' ELLIPSIS='...'
		BOX_TL='+' BOX_TR='+' BOX_BL='+' BOX_BR='+' BOX_H='-' BOX_V='|' BAR='=' BAR_AT='|'
		;;
	esac

	local family format ok=0 reached=0 json_parts='' re
	LOCAL_FAMILY=
	CHECKED_IP=
	RESULTS=
	format=kv
	[ "$JSON" = 1 ] && format=json
	for family in $FAMILIES; do
		[ -t 2 ] && [ "$JSON" = 0 ] && printf '\r%s' "$(tf checking "$family")" >&2
		fetch "$family" "$format"
		[ -t 2 ] && [ "$JSON" = 0 ] && printf '\r\033[K' >&2
		[ -n "$STATUS" ] && reached=1
		# Local checks go over the first family that reached the server (IPv4 on a dual-stack machine).
		[ -n "$STATUS" ] && [ -z "$LOCAL_FAMILY" ] && LOCAL_FAMILY=$family
		if [ "$JSON" = 1 ]; then
			re='"aiRegions":\{"version":"[^"]*","chatgpt":"([A-Z,]*)","claude":"([A-Z,]*)"\}'
			if [ -z "${AI_JSON_LISTS-}" ] && [[ $BODY =~ $re ]]; then
				AI_JSON_LISTS="chatgpt=${BASH_REMATCH[1]}"$'\n'"claude=${BASH_REMATCH[2]}"
			fi
			case $BODY in
			'{'*) json_parts="$json_parts,\"ipv$family\":$BODY" ;;
			*) json_parts="$json_parts,\"ipv$family\":{\"error\":\"unreachable\"}" ;;
			esac
			[ "$STATUS" = 200 ] && ok=1
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
			# A proxy carried this family's request out over the other one; the server answers without counting it. The address
			# it arrived from is named unless the header already shows it (the other family's own result).
			if [ -n "$CHECKED_IP" ] && [ "$(v ip)" = "$CHECKED_IP" ]; then
				printf -v "FAIL_$family" '%s' "$(tf other_family_shown "$family" "$(v arrivedFamily)")"
			else
				printf -v "FAIL_$family" '%s' "$(tf other_family "$family" "$(v arrivedFamily)" "$(v ip)")"
			fi
			printf -v "FAIL_STYLE_$family" '%s' dim
		elif [ "$STATUS" != 200 ]; then
			printf -v "FAIL_$family" '%s' "$(failure "$STATUS")"
		else
			RESULTS="$RESULTS $family"
			[ "$family" = "$LOCAL_FAMILY" ] && CHECKED_IP=$(v ip)
			ok=1
		fi
	done

	[ -n "$LOCAL_FAMILY" ] && run_local
	local output
	if [ "$JSON" = 1 ]; then
		[ -n "$LOCAL_FAMILY" ] && json_parts="$json_parts,\"local\":$(local_json)"
		output="{\"cli\":\"$VERSION\"$json_parts}"
	else
		output=$(render_report)
	fi
	# Cells are padded to their width; the last one leaves trailing spaces behind.
	output=$(printf '%s\n' "$output" | sed 's/ *$//')
	printf '%s\n' "$output"
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
