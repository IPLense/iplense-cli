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

VERSION=1.0.0
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
	title) zh='IPLense 自检'; en='IPLense self-check' ;;
	checking) zh='正在检测 IPv%s…'; en='Checking IPv%s…' ;;
	no_conn) zh='无连接'; en='No connection' ;;
	other_family) zh='无 IPv%s 出口：请求以 IPv%s 到达（%s）'; en='No IPv%s exit: the request arrived over IPv%s (%s)' ;;
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
	local_title) zh='本地检测'; en='Local checks' ;;
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
			'  -l zh|en   输出语言（默认按 LANG）' \
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
			'  -l zh|en   Output language (default from LANG)' \
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

paint() {
	if [ "$COLOR" = 1 ] && [ -n "$1" ] && [ -n "$2" ]; then
		local code
		case $1 in
		pos) code=32 ;; neu) code=33 ;; neg) code=31 ;; dim) code=2 ;; bold) code=1 ;; head) code='1;36' ;; *) code=0 ;;
		esac
		printf '\033[%sm%s\033[0m' "$code" "$2"
	else
		printf '%s' "$2"
	fi
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

type_tone() {
	case $1 in ISP) printf pos ;; IDC | Error) printf neg ;; Business) printf neu ;; *) printf dim ;; esac
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

risk_tone() {
	if [ "$1" -le 20 ]; then printf pos; elif [ "$1" -le 50 ]; then printf neu; else printf neg; fi
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

render_family() {
	local family=$1 ip nature property score purity tone name company ctype
	F=$family
	ip=$(v ip)
	printf '%s  %s\n' "$(paint head "IPv$family")" "$(paint bold "$ip")"

	# Ownership and location; the Quick types read as the web result card writes them (ISP, IDC).
	name=$(v quick.asn.name)
	printf '  %s\n' "$(joined "AS$(v quick.asn.number)" "$name" "$(v quick.asn.type)")"
	company=$(v quick.company.name)
	ctype=$(v quick.company.type)
	if [ -n "$company" ] && [ "$company" != "$name" ]; then
		printf '  %s  %s\n' "$(paint dim "$(l operator)")" "$(joined "$company" "$ctype")"
	fi
	printf '  %s\n\n' "$(joined "$(v quick.location.country)" "$(v quick.location.region)" "$(v quick.location.city)")"

	# The Quick result: score, purity risk value (lower is cleaner), then the two property badges without labels, as on the
	# web result card; each coloured by value.
	score=$(v quick.score)
	purity=$(v quick.purity.value)
	nature=$(v quick.ipNature)
	property=$(v quick.ipProperty)
	local line="  "
	if [ -n "$score" ]; then
		if [ "$score" -ge 80 ]; then tone=pos; elif [ "$score" -ge 60 ]; then tone=neu; else tone=neg; fi
		line="$line$(paint dim "$(l score)") $(paint "$tone" "$score")    "
	fi
	if [ -n "$purity" ]; then
		case $(v quick.purity.state) in good) tone=pos ;; average) tone=neu ;; poor) tone=neg ;; *) tone='' ;; esac
		line="$line$(paint dim "$(l purity)") $(paint dim "$(l purityRisk)") $(paint "$tone" "$purity/100")    "
	fi
	case $nature in Native) tone=pos ;; Broadcast) tone=neu ;; Unknown | '') tone=dim ;; *) tone=neg ;; esac
	line="$line$(paint "$tone" "$(l "nature_${nature:-Unknown}")")$(paint dim "$SEP")"
	case $property in Residential | HomeBroadband) tone=pos ;; Unknown | '') tone=dim ;; *) tone=neg ;; esac
	line="$line$(paint "$tone" "$(l "property_${property:-Unknown}")")"
	printf '%s\n\n' "$line"

	render_sources
	render_factors
	printf '  %s  %s\n' "$(paint dim "$(t report)")" "$BASE/$LANG_UI/ip/$ip"
}

# One row per provider: location, usage and company type, risk score. A row whose every module is out of quota, or
# failed, says so once.
render_sources() {
	local name_w=15 type_w=10 risk_w=6 loc_w provider li ti ri state states loc usage company score level
	if [ "$COLS" -ge 100 ]; then type_w=12; fi
	# The risk column is as wide as its heading (the numbers are right-aligned under it).
	risk_w=$(width "$(l colRiskValue)")
	[ "$risk_w" -lt 6 ] && risk_w=6
	loc_w=$((COLS - 2 - name_w - 2 * type_w - risk_w - 2))
	[ "$loc_w" -gt 44 ] && loc_w=44

	printf '  %s%s%s%s%s\n' "$(cell "$(l colSource)" "$name_w" dim)" "$(cell "$(l location)" "$loc_w" dim)" \
		"$(cell "$(l usageType)" "$type_w" dim)" "$(cell "$(l companyType)" "$type_w" dim)" "$(cell "$(l colRiskValue)" "$risk_w" dim r)"

	local list
	IFS=$'\n' read -r -d '' -a list < <(providers)
	for provider in "${list[@]}"; do
		li=$(index_of locations "$provider")
		ti=$(index_of types "$provider")
		ri=$(index_of riskSources "$provider")
		states=''
		[ -n "$li" ] && states="$states $(v "professional.locations.$li.state")"
		[ -n "$ti" ] && states="$states $(row_type_state "$ti")"
		[ -n "$ri" ] && states="$states $(row_risk_state "$ri")"
		printf '  %s' "$(cell "$(brand "$provider")" "$name_w" bold)"
		case " $states " in
		*Success*) ;;
		*Quota*) printf '%s\n' "$(paint neu "$(l rowQuota)")"; continue ;;
		*Error*) printf '%s\n' "$(paint neg "$(l rowError)")"; continue ;;
		esac

		# Location: country code, then city (region too when the terminal is wide).
		loc=''
		if [ -n "$li" ]; then
			state=$(v "professional.locations.$li.state")
			if [ "$state" = Success ]; then
				if [ "$COLS" -ge 100 ]; then
					loc=$(joined "$(v "professional.locations.$li.countryCode")" "$(v "professional.locations.$li.region")" "$(v "professional.locations.$li.city")")
				else
					loc=$(joined "$(v "professional.locations.$li.countryCode")" "$(v "professional.locations.$li.city")")
				fi
				printf '%s' "$(GAP=2 cell "$loc" "$loc_w" '')"
			else
				printf '%s' "$(module_cell "$state" "$loc_w")"
			fi
		else
			printf '%s' "$(cell "$MARK_NONE" "$loc_w" dim)"
		fi

		# Usage and company type.
		if [ -n "$ti" ] && [ "$(row_type_state "$ti")" = Success ]; then
			usage=$(v "professional.types.$ti.usageType")
			company=$(v "professional.types.$ti.companyType")
			printf '%s' "$(cell "$(type_text "$usage")" "$type_w" "$(type_tone "$usage")")"
			if [ -n "$company" ]; then
				printf '%s' "$(cell "$(type_text "$company")" "$type_w" "$(type_tone "$company")")"
			else
				printf '%s' "$(cell "$MARK_NONE" "$type_w" dim)"
			fi
		elif [ -n "$ti" ]; then
			printf '%s' "$(module_cell "$(row_type_state "$ti")" $((2 * type_w)))"
		else
			printf '%s%s' "$(cell "$MARK_NONE" "$type_w" dim)" "$(cell "$MARK_NONE" "$type_w" dim)"
		fi

		# Risk score: the number, or the provider's level when it gives no number.
		if [ -n "$ri" ] && [ "$(row_risk_state "$ri")" = Success ]; then
			score=$(v "professional.riskSources.$ri.score.value")
			level=$(v "professional.riskSources.$ri.score.level")
			if [ -n "$score" ]; then
				score=${score%%.*}
				printf '%s' "$(cell "$score" "$risk_w" "$(risk_tone "$score")" r)"
			elif [ -n "$level" ]; then
				level=$(printf '%s' "$level" | tr '[:upper:]' '[:lower:]')
				case $level in low) tone=pos ;; medium) tone=neu ;; *) tone=neg ;; esac
				printf '%s' "$(cell "$(l "level_$level")" "$risk_w" "$tone" r)"
			else
				printf '%s' "$(cell "$MARK_NONE" "$risk_w" dim r)"
			fi
		elif [ -n "$ri" ]; then
			printf '%s' "$(module_cell "$(row_risk_state "$ri")" "$risk_w" r)"
		else
			printf '%s' "$(cell "$MARK_NONE" "$risk_w" dim r)"
		fi
		printf '\n'
	done
	printf '\n'
}

module_cell() {
	case $1 in
	QuotaUnavailable) cell "$(l quotaUnavailable)" "$2" neu "${3-}" ;;
	*) cell "$(l error)" "$2" neg "${3-}" ;;
	esac
}

# A type row's state: quota or failure in either field stands for the whole row (as on the web).
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

render_factors() {
	local name_w=15 col_w=8 provider ri column mark list names=() rows=() n
	[ "$LANG_UI" = zh ] && col_w=7
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
	printf '  %s' "$(cell "$(l statRiskHits)" "$name_w" dim)"
	for column in $COLUMNS_RISK; do printf '%s' "$(cell "$(l "column_${column%%:*}")" "$col_w" dim)"; done
	printf '\n'
	n=0
	while [ "$n" -lt "${#rows[@]}" ]; do
		printf '  %s' "$(cell "$(brand "${names[$n]}")" "$name_w" bold)"
		signals=$(signal_states "${rows[$n]}")
		for column in $COLUMNS_RISK; do
			mark=$(risk_mark "$signals" "${column#*:}")
			case $mark in
			detected) printf '%s' "$(cell "$MARK_HIT" "$col_w" neg)" ;;
			clear) printf '%s' "$(cell "$MARK_CLEAR" "$col_w" pos)" ;;
			*) printf '%s' "$(cell "$MARK_NONE" "$col_w" dim)" ;;
			esac
		done
		printf '\n'
		n=$((n + 1))
	done
	printf '  %s %s  %s %s  %s %s\n\n' "$(paint neg "$MARK_HIT")" "$(l cell_detected)" "$(paint pos "$MARK_CLEAR")" "$(l cell_clear)" \
		"$(paint dim "$MARK_NONE")" "$(l cell_none)"
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
	local row tone name_w=18 status_w=0 w IFS=$'\n'
	set -f
	# The status column is as wide as its longest word.
	for row in $LOCAL_RESULTS; do
		split_result "$row"
		w=$(width "$(local_status "$STATUS")")
		[ "$w" -gt "$status_w" ] && status_w=$w
	done
	status_w=$((status_w + 2))
	# When the platforms leave through another exit than the IP checked above (split routing), the title names it.
	if [ -n "$LOCAL_EXIT" ] && [ -n "$CHECKED_IP" ] && [ "$LOCAL_EXIT" != "$CHECKED_IP" ]; then
		printf '%s%s\n' "$(paint head "$(t local_title)")" "$(paint dim "${SEP}IPv$LOCAL_FAMILY${SEP}$(tf local_exit "$LOCAL_EXIT")")"
		printf '  %s\n' "$(paint dim "$(t local_exit_note)")"
	else
		printf '%s%s\n' "$(paint head "$(t local_title)")" "$(paint dim "${SEP}IPv$LOCAL_FAMILY")"
	fi
	for row in $LOCAL_RESULTS; do
		split_result "$row"
		case $STATUS in available | supported) tone=pos ;; unavailable | unsupported) tone=neg ;; originals_only) tone=neu ;; *) tone=dim ;; esac
		printf '  %s%s%s\n' "$(cell "$(local_name "$KEY")" "$name_w" bold)" "$(cell "$(local_status "$STATUS")" "$status_w" "$tone")" "$REGION"
	done
	set +f
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
	if [ -t 1 ] && [ -z "${NO_COLOR-}" ] && [ "${TERM-}" != dumb ]; then COLOR=1; fi
	COLS=80
	if [ -t 1 ]; then
		COLS=${COLUMNS:-$(tput cols 2>/dev/null || printf 80)}
		case $COLS in '' | *[!0-9]*) COLS=80 ;; esac
	elif [ -n "${COLUMNS-}" ]; then
		case $COLUMNS in *[!0-9]* | '') ;; *) COLS=$COLUMNS ;; esac
	fi
	[ "$COLS" -lt 72 ] && COLS=72
	[ "$COLS" -gt 120 ] && COLS=120
	case ${LC_ALL:-${LC_CTYPE:-${LANG:-}}} in
	*UTF-8* | *utf8* | *UTF8* | *utf-8*) MARK_HIT='●' MARK_CLEAR='·' MARK_NONE='–' SEP=' · ' ELLIPSIS='…' ;;
	*) MARK_HIT='x' MARK_CLEAR='.' MARK_NONE='-' SEP=' / ' ELLIPSIS='...' ;;
	esac

	local family format ok=0 reached=0 json_parts='' text='' status_line re
	LOCAL_FAMILY=
	CHECKED_IP=
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
		if [ -z "$STATUS" ]; then
			text=$text$(printf '%s  %s' "$(paint head "IPv$family")" "$(paint dim "$(t no_conn)")")$'\n\n'
			continue
		fi
		parse_kv "$family" "$BODY"
		F=$family
		if [ "$(v schema)" != "$SCHEMA" ]; then
			status_line=$(t schema)
		elif [ "$(v error)" = family_mismatch ]; then
			# A proxy carried this family's request out over the other one; the server answers without counting it.
			status_line=$(tf other_family "$family" "$(v arrivedFamily)" "$(v ip)")
			text=$text$(printf '%s  %s' "$(paint head "IPv$family")" "$(paint dim "$status_line")")$'\n\n'
			continue
		elif [ "$STATUS" != 200 ]; then
			status_line=$(failure "$STATUS")
		else
			text=$text$(render_family "$family")$'\n\n'
			[ "$family" = "$LOCAL_FAMILY" ] && CHECKED_IP=$(v ip)
			ok=1
			continue
		fi
		text=$text$(printf '%s  %s' "$(paint head "IPv$family")" "$(paint neu "$status_line")")$'\n\n'
	done

	if [ -n "$LOCAL_FAMILY" ]; then
		run_local
		if [ "$JSON" = 1 ]; then
			json_parts="$json_parts,\"local\":$(local_json)"
		else
			text=$text$(render_local)$'\n'
		fi
	fi

	local output
	if [ "$JSON" = 1 ]; then
		output="{\"cli\":\"$VERSION\"$json_parts}"
	else
		output="$(paint bold "$(t title)")  $(paint dim "$VERSION")"$'\n\n'$text
		output=${output%$'\n'}
	fi
	# Cells are padded to their width; the last one leaves trailing spaces behind.
	output=$(printf '%s\n' "$output" | sed 's/ *$//')
	printf '%s\n' "$output"
	if [ -n "$OUT" ]; then
		# The saved copy carries no colour codes.
		local LC_ALL=C plain=$output
		plain=$(printf '%s' "$plain" | sed $'s/\033\\[[0-9;]*m//g')
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
