#!/bin/sh

set -eu

APPNAME="passwall"
RULES_DIR="/usr/share/${APPNAME}/rules"
DIRECT_HOST_FILE="${RULES_DIR}/direct_host"
PASSWALL_TMP_DIR="/tmp/etc/passwall_tmp"

ZAPRET_INIT="/etc/init.d/zapret"
ZAPRET_UCI_CONFIG="zapret"
ZAPRET_STRATEGIES_FILE="/etc/zapret/strategies.list"
ZAPRET_CONFIG_FILE="/etc/zapret/config"

YOUTUBE_TEST_URL="${YOUTUBE_TEST_URL:-https://www.youtube.com/generate_204}"
STRATEGY_SETTLE_SEC="${STRATEGY_SETTLE_SEC:-3}"
PASSWALL_RELOAD="${PASSWALL_RELOAD:-0}"

DIRECT_HOST_BLOCK_BEGIN="# BEGIN PASSWALL YOUTUBE DIRECT"
DIRECT_HOST_BLOCK_END="# END PASSWALL YOUTUBE DIRECT"

log() {
	logger -t "passwall_youtube_zapret" -- "$*"
}

command_exists() {
	command -v "$1" >/dev/null 2>&1
}

probe_youtube() {
	if command_exists curl; then
		curl -fsS --connect-timeout 5 --max-time 10 -o /dev/null "$YOUTUBE_TEST_URL"
		return $?
	fi
	if command_exists wget; then
		wget -q --spider -T 10 "$YOUTUBE_TEST_URL"
		return $?
	fi
	if command_exists uclient-fetch; then
		uclient-fetch -q -O /dev/null "$YOUTUBE_TEST_URL"
		return $?
	fi
	return 1
}

ensure_rules_dir() {
	if [ ! -d "$RULES_DIR" ]; then
		mkdir -p "$RULES_DIR"
	fi
	if [ ! -f "$DIRECT_HOST_FILE" ]; then
		: >"$DIRECT_HOST_FILE"
	fi
}

remove_direct_host_block() {
	if [ ! -f "$DIRECT_HOST_FILE" ]; then
		return 0
	fi
	if ! grep -q "$DIRECT_HOST_BLOCK_BEGIN" "$DIRECT_HOST_FILE"; then
		return 0
	fi
	awk "
		\$0 == \"${DIRECT_HOST_BLOCK_BEGIN}\" {skip=1; next}
		\$0 == \"${DIRECT_HOST_BLOCK_END}\" {skip=0; next}
		skip == 1 {next}
		{print}
	" "$DIRECT_HOST_FILE" >"${DIRECT_HOST_FILE}.tmp"
	mv "${DIRECT_HOST_FILE}.tmp" "$DIRECT_HOST_FILE"
}

add_direct_host_block() {
	remove_direct_host_block
	cat <<EOF >>"$DIRECT_HOST_FILE"
${DIRECT_HOST_BLOCK_BEGIN}
youtube.com
www.youtube.com
youtube-nocookie.com
youtu.be
ytimg.com
googlevideo.com
yt3.ggpht.com
yt4.ggpht.com
ggpht.com
gvt1.com
gvt2.com
gvt3.com
gvt4.com
googleapis.com
${DIRECT_HOST_BLOCK_END}
EOF
}

clean_passwall_dns_cache() {
	rm -rf "${PASSWALL_TMP_DIR}"/dns_* >/dev/null 2>&1 || true
}

reload_passwall_if_needed() {
	if [ "$PASSWALL_RELOAD" -eq 1 ] && [ -x /etc/init.d/passwall ]; then
		/etc/init.d/passwall reload >/dev/null 2>&1 || /etc/init.d/passwall restart >/dev/null 2>&1 || true
	fi
}

set_zapret_strategy() {
	local strategy="$1"
	if uci -q get "${ZAPRET_UCI_CONFIG}.@zapret[0]" >/dev/null 2>&1; then
		uci -q set "${ZAPRET_UCI_CONFIG}.@zapret[0].strategy=${strategy}"
		uci -q commit "${ZAPRET_UCI_CONFIG}"
		return 0
	fi
	if [ -f "$ZAPRET_CONFIG_FILE" ]; then
		if grep -q '^STRATEGY=' "$ZAPRET_CONFIG_FILE"; then
			sed -i "s/^STRATEGY=.*/STRATEGY=\"${strategy}\"/" "$ZAPRET_CONFIG_FILE"
		else
			printf '\nSTRATEGY="%s"\n' "$strategy" >>"$ZAPRET_CONFIG_FILE"
		fi
		return 0
	fi
	return 1
}

enable_zapret() {
	if [ -x "$ZAPRET_INIT" ]; then
		"$ZAPRET_INIT" enable >/dev/null 2>&1 || true
		"$ZAPRET_INIT" restart >/dev/null 2>&1 || "$ZAPRET_INIT" start >/dev/null 2>&1 || true
	fi
}

disable_zapret() {
	if uci -q get "${ZAPRET_UCI_CONFIG}.@zapret[0].enabled" >/dev/null 2>&1; then
		uci -q set "${ZAPRET_UCI_CONFIG}.@zapret[0].enabled=0"
		uci -q commit "${ZAPRET_UCI_CONFIG}"
	fi
	if [ -x "$ZAPRET_INIT" ]; then
		"$ZAPRET_INIT" stop >/dev/null 2>&1 || true
		"$ZAPRET_INIT" disable >/dev/null 2>&1 || true
	fi
}

load_strategies() {
	if [ -f "$ZAPRET_STRATEGIES_FILE" ]; then
		grep -v '^[[:space:]]*#' "$ZAPRET_STRATEGIES_FILE" | sed '/^[[:space:]]*$/d'
		return 0
	fi
	cat <<'EOF'
nfqws
nfqws,split
nfqws,split2
nfqws,disorder
nfqws,disorder2
nfqws,split+disorder
nfqws,split2+disorder
nfqws,split2+disorder2
nfqws,split2+fakedsn
nfqws,split2+fakedsn+disorder
nfqws,split2+fakedsn+disorder2
nfqws,split2+fakedsn+disorder2+tls
nfqws,split2+fakedsn+disorder2+tls13
nfqws,split2+fakedsn+disorder2+md5sig
nfqws,split2+fakedsn+disorder2+md5sig+tls
nfqws,split2+fakedsn+disorder2+md5sig+tls13
EOF
}

main() {
	ensure_rules_dir
	clean_passwall_dns_cache

	local strategy
	local success=0
	local strategies
	strategies=$(load_strategies)

	if [ -z "$strategies" ]; then
		log "No strategies found; disabling zapret and adding YouTube domains to direct list."
		add_direct_host_block
		clean_passwall_dns_cache
		reload_passwall_if_needed
		disable_zapret
		exit 1
	fi

	IFS='\n'
	for strategy in $strategies; do
		log "Trying zapret strategy: ${strategy}"
		if ! set_zapret_strategy "$strategy"; then
			log "Unable to set strategy: ${strategy}"
			continue
		fi
		enable_zapret
		sleep "$STRATEGY_SETTLE_SEC"
		if probe_youtube; then
			log "Strategy works: ${strategy}. Removing YouTube direct list and keeping zapret enabled."
			remove_direct_host_block
			clean_passwall_dns_cache
			reload_passwall_if_needed
			success=1
			break
		else
			log "Strategy failed: ${strategy}"
		fi
	done
	unset IFS

	if [ "$success" -eq 1 ]; then
		exit 0
	fi

	log "All strategies failed; adding YouTube domains to direct list and disabling zapret."
	add_direct_host_block
	clean_passwall_dns_cache
	reload_passwall_if_needed
	disable_zapret
	exit 1
}

main "$@"
