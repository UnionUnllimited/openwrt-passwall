local api = require "luci.passwall.api"
local has_xray = api.finded_com("xray")
local has_singbox = api.finded_com("sing-box")
api.set_default_cbi()

m = Map()

-- [[ Rule Settings ]]--
s = m:section(NamedSection, "@global_rules[0]", "global_rules", translate("Rule status"))

--[[
o = s:option(Flag, "adblock", translate("Enable adblock"))
o.rmempty = false
]]--

---- RuProxy URL (домены)
o = s:option(DynamicList, "ru_proxy_url", translatef("%s Update URL", "RuProxy"))
o:value("https://raw.githubusercontent.com/1andrevich/Re-filter-lists/main/domains_all.lst", translate("Re-filter-lists/domains_all"))
o:value("https://antifilter.download/list/domains.lst", translate("antifilter.download/domains (large)"))
o.default = o.keylist[1]

---- RuProxyIp URL
o = s:option(DynamicList, "ru_proxy_ip_url", translatef("%s Update URL", "RuProxyIp"))
o:value("https://antifilter.download/list/allyouneed.lst", translate("antifilter.download/allyouneed"))
o:value("https://antifilter.download/list/ipsum.lst", translate("antifilter.download/ipsum"))
o:value("https://raw.githubusercontent.com/1andrevich/Re-filter-lists/main/ipsum.lst", translate("Re-filter-lists/ipsum"))
o.default = o.keylist[1]

---- RuDirect URL (домены)
o = s:option(DynamicList, "ru_direct_url", translatef("%s Update URL", "RuDirect"))

---- RuDirectIp URL
o = s:option(DynamicList, "ru_direct_ip_url", translatef("%s Update URL", "RuDirectIp"))
o:value("https://raw.githubusercontent.com/ipverse/rir-ip/master/country/ru/ipv4-aggregated.txt", translate("ipverse/rir-ip RU IPv4"))
o:value("https://raw.githubusercontent.com/ipverse/rir-ip/master/country/ru/ipv6-aggregated.txt", translate("ipverse/rir-ip RU IPv6"))

if has_xray or has_singbox then
	o = s:option(Value, "geoip_url", translate("GeoIP Update URL"))
	o:value("https://github.com/Loyalsoldier/geoip/releases/latest/download/geoip.dat", translate("Loyalsoldier/geoip"))
	o:value("https://github.com/MetaCubeX/meta-rules-dat/releases/latest/download/geoip.dat", translate("MetaCubeX/geoip"))
	o:value("https://cdn.jsdelivr.net/gh/Loyalsoldier/geoip@release/geoip.dat", translate("Loyalsoldier/geoip (CDN)"))
	o:value("https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geoip.dat", translate("MetaCubeX/geoip (CDN)"))
	o.default = o.keylist[1]

	o = s:option(Value, "geosite_url", translate("Geosite Update URL"))
	o:value("https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat", translate("Loyalsoldier/geosite"))
	o:value("https://github.com/MetaCubeX/meta-rules-dat/releases/latest/download/geosite.dat", translate("MetaCubeX/geosite"))
	o:value("https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geosite.dat", translate("Loyalsoldier/geosite (CDN)"))
	o:value("https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geosite.dat", translate("MetaCubeX/geosite (CDN)"))
	o.default = o.keylist[1]

	o = s:option(Value, "v2ray_location_asset", translate("Location of Geo rule files"), translate("This variable specifies a directory where geoip.dat and geosite.dat files are."))
	o.default = "/usr/share/v2ray/"
	o.placeholder = "/usr/share/v2ray/"
	o.rmempty = false

	if api.is_finded("geoview") then
		o = s:option(Flag, "geo2rule", translate("Generate Rule List from Geo"))
		o.default = 0
		o.rmempty = false
		o.description = translate("Generate rule lists such as GFW, China domains, and China IP ranges based on Geo files.") .. "<br><font color='red'>" ..
			translate("When manually updating with this option enabled, rules will be regenerated from existing Geo files even if no new version is available.") .. "</font>"

		o = s:option(Flag, "enable_geoview", translate("Enable Geo Data Parsing"))
		o.default = 0
		o.rmempty = false
		o.description = "<ul>"
			.. "<li>" .. translate("Experimental feature.") .. "</li>"
			.. "<li>" .. "1." .. translate("Parses and preloads GeoIP/Geosite data to improve Sing-box/Xray routing performance.") .. "</li>"
			.. "<li>" .. "2." .. translate("Once enabled, the rule list can support GeoIP/Geosite rules.") .. "</li>"
			.. "</ul>"
		function o.write(self, section, value)
			local old = m:get(section, self.option) or "0"
			if old ~= value then
				m:set("@global[0]", "flush_set", "1")
			end
			return Flag.write(self, section, value)
		end
	end
end

o = s:option(ListValue, "update_week_mode", translate("Auto Update Mode"))
o:value("", translate("Disable"))
o:value(8, translate("Loop Mode"))
o:value(7, translate("Every day"))
o:value(1, translate("Every Monday"))
o:value(2, translate("Every Tuesday"))
o:value(3, translate("Every Wednesday"))
o:value(4, translate("Every Thursday"))
o:value(5, translate("Every Friday"))
o:value(6, translate("Every Saturday"))
o:value(0, translate("Every Sunday"))

o = s:option(Value, "update_time_mode", translate("Update Time"))
for t = 0, 23 do o:value(t .. ":00") end
o.default = "0:00"
o.datatype = "timehhmm"
o:depends("update_week_mode", "0")
o:depends("update_week_mode", "1")
o:depends("update_week_mode", "2")
o:depends("update_week_mode", "3")
o:depends("update_week_mode", "4")
o:depends("update_week_mode", "5")
o:depends("update_week_mode", "6")
o:depends("update_week_mode", "7")

o = s:option(ListValue, "update_interval_mode", translate("Update Interval(hour)"))
for t = 1, 24 do o:value(t, t .. " " .. translate("hour")) end
o.default = 2
o:depends("update_week_mode", "8")
o.rmempty = true

---- 更新选项，始终被js隐藏
local flags = {
	"ru_proxy_update", "ru_proxy_ip_update", "ru_direct_update",
	"ru_direct_ip_update", "geoip_update", "geosite_update"
}
for _, f in ipairs(flags) do
	o = s:option(Flag, f)
	o.rmempty = false
end

s:appendTemplate("/rule/rule_version")

if has_xray or has_singbox then
	m:appendTemplate("/rule/shunt_rule_list")

	if luci.http.formvalue("cbi.submit") == "1" then
		local group_order = luci.http.formvaluetable("group.order")
		if group_order then
			for k, v in pairs(group_order) do
				if v and v~= "" then
					local new_order = {}
					string.gsub(v, "[^" .. " " .. "]+", function(w)
						new_order[#new_order + 1] = w
					end)
					for idx, name in ipairs(new_order) do
						m.uci:reorder(m.config, name, idx - 1)
					end
				end
			end
		end
	end
end

return api.return_map(m)
