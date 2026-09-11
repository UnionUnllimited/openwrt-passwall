#!/bin/sh
# Обновление luci-app-passwall на роутере до этого форка, поверх установки,
# сделанной файлами (мимо пакетного менеджера).
#
# Переносит списки China List на имена Ru*: chnlist -> RuProxy,
# chnroute(+chnroute6) -> RuProxyIp, и опцию chn_list -> ru_proxy_mode.
#
# Не трогает: /etc/config/*, пользовательские файлы в rules/
# (direct_host, proxy_host, block_* и прочие), /etc/uci-defaults.

set -e

BRANCH="${BRANCH:-my-26.9.1}"
REPO="${REPO:-UnionUnllimited/openwrt-passwall}"
RULES=/usr/share/passwall/rules
WORK=/tmp/pw-update

say() { echo "==> $*"; }

[ -f /usr/lib/lua/luci/controller/passwall.lua ] || {
	echo "passwall не найден в /usr/lib/lua/luci — обновлять нечего." >&2
	exit 1
}

say "Бэкап"
tar -czf /root/passwall-luci.bak.tar.gz \
	/usr/lib/lua/luci/controller/passwall.lua \
	/usr/lib/lua/luci/passwall \
	/usr/lib/lua/luci/model/cbi/passwall \
	/usr/lib/lua/luci/view/passwall \
	/www/luci-static/resources/view/passwall 2>/dev/null || true
rm -rf /root/passwall.bak
cp -a /usr/share/passwall /root/passwall.bak
cp -a /etc/config/passwall /root/passwall.config.bak
echo "    /root/passwall-luci.bak.tar.gz, /root/passwall.bak, /root/passwall.config.bak"

say "Скачивание ветки $BRANCH"
rm -rf "$WORK"
mkdir -p "$WORK"
curl -fsSL -o "$WORK/src.tar.gz" \
	"https://github.com/$REPO/archive/refs/heads/$BRANCH.tar.gz"
tar -xzf "$WORK/src.tar.gz" -C "$WORK"

SRC=$(find "$WORK" -maxdepth 2 -type d -name luci-app-passwall | head -1)
[ -n "$SRC" ] || { echo "не нашёл luci-app-passwall в архиве" >&2; exit 1; }

say "Копирование кода"
cp -a "$SRC/luasrc/."                  /usr/lib/lua/luci/
cp -a "$SRC/htdocs/."                  /www/
cp -a "$SRC/root/etc/init.d/."         /etc/init.d/
cp -a "$SRC/root/etc/hotplug.d/."      /etc/hotplug.d/
cp -a "$SRC/root/usr/share/rpcd/."     /usr/share/rpcd/
cp -a "$SRC/root/usr/share/ucitrack/." /usr/share/ucitrack/
# только файлы верхнего уровня: rules/ с пользовательскими списками не трогаем
find "$SRC/root/usr/share/passwall" -maxdepth 1 -type f \
	-exec cp -a {} /usr/share/passwall/ \;
rm -f /usr/lib/lua/luci/view/passwall/rule_list/js.htm
chmod +x /usr/share/passwall/*.sh /etc/init.d/passwall /etc/init.d/passwall_server

say "Перенос списков"
[ -f "$RULES/chnlist" ]  && mv -f "$RULES/chnlist"  "$RULES/RuProxy"   && echo "    chnlist -> RuProxy"
[ -f "$RULES/chnroute" ] && mv -f "$RULES/chnroute" "$RULES/RuProxyIp" && echo "    chnroute -> RuProxyIp"
[ -f "$RULES/chnroute6" ] && {
	cat "$RULES/chnroute6" >> "$RULES/RuProxyIp"
	rm -f "$RULES/chnroute6"
	echo "    chnroute6 дописан в RuProxyIp"
}
rm -f "$RULES/gfwlist" "$RULES"/*.nft
for f in RuProxy RuProxyIp RuDirect RuDirectIp; do
	[ -f "$RULES/$f" ] || : > "$RULES/$f"
done

say "Перенос настроек"
MODE=$(uci -q get passwall.@global[0].chn_list || echo proxy)
uci -q set passwall.@global[0].ru_proxy_mode="$MODE"
uci -q delete passwall.@global[0].chn_list || true
uci -q delete passwall.@global[0].use_gfw_list || true
uci commit passwall
echo "    ru_proxy_mode=$MODE"

say "Перезапуск"
rm -rf /tmp/luci-modulecache/ /tmp/luci-indexcache*
/etc/init.d/rpcd restart
/etc/init.d/passwall restart

rm -rf "$WORK"

say "Готово. Строк в списках:"
wc -l "$RULES/RuProxy" "$RULES/RuProxyIp" "$RULES/RuDirect" "$RULES/RuDirectIp"
