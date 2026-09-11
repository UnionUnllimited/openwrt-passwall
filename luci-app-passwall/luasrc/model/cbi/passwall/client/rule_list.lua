local api = require "luci.passwall.api"
local fs = api.fs
local sys = api.sys
local datatypes = api.datatypes
local path = string.format("/usr/share/%s/rules/", api.appname)

api.set_default_cbi()

m = Map()
m.apply_on_parse = true

function clean_text(text)
	local nbsp = string.char(0xC2, 0xA0) -- 不间断空格（U+00A0）
	local fullwidth_space = string.char(0xE3, 0x80, 0x80) -- 全角空格（U+3000）
	return text
		:gsub("\t", " ")
		:gsub(nbsp, " ")
		:gsub(fullwidth_space, " ")
		:gsub("^%s+", "")
		:gsub("%s+$", "\n")
		:gsub("\r\n", "\n")
		:gsub("[ \t]*\n[ \t]*", "\n")
end

-- [[ Rule List Settings ]]--
s = m:section(TypedSection, "global_rules")
s.anonymous = true

s:tab("ru_proxy_list", translate("RuProxy List"))
s:tab("ru_direct_list", translate("RuDirect List"))
s:tab("direct_list", translate("Direct List"))
s:tab("proxy_list", translate("Proxy List"))
s:tab("block_list", translate("Block List"))
s:tab("lan_ip_list", translate("Lan IP List"))
s:tab("route_hosts", translate("Route Hosts"))

-- Списки Ru* заполняются вручную или автообновлением по URL,
-- режим каждого (Выкл/Директ/Прокси) задаётся в «Базовых настройках».
local function ru_host_option(tab, name, description)
	local file = path .. name
	local o = s:taboption(tab, TextValue, name, "", "<font color='red'>" .. description .. "</font>")
	o.rows = 15
	o.wrap = "off"
	o.cfgvalue = function(self, section)
		return fs.readfile(file) or ""
	end
	o.write = function(self, section, value)
		fs.writefile(file, value:gsub("\r\n", "\n"))
		sys.call("rm -rf /tmp/etc/passwall_tmp/dns_*")
	end
	o.remove = function(self, section, value)
		fs.writefile(file, "")
		sys.call("rm -rf /tmp/etc/passwall_tmp/dns_*")
	end
	o.validate = function(self, value)
		local hosts = {}
		value = clean_text(value)
		string.gsub(value, '[^' .. "\r\n" .. ']+', function(w) table.insert(hosts, api.trim(w)) end)
		for index, host in ipairs(hosts) do
			if host ~= "" and not host:find("^#") and not host:find("^geosite:") then
				if not datatypes.hostname(host) then
					return nil, host .. " " .. translate("Not valid domain name, please re-enter!")
				end
			end
		end
		return value
	end
	return o
end

local function ru_ip_option(tab, name, description)
	local file = path .. name
	local o = s:taboption(tab, TextValue, name, "", "<font color='red'>" .. description .. "</font>")
	o.rows = 15
	o.wrap = "off"
	o.cfgvalue = function(self, section)
		return fs.readfile(file) or ""
	end
	o.write = function(self, section, value)
		fs.writefile(file, value:gsub("\r\n", "\n"))
	end
	o.remove = function(self, section, value)
		fs.writefile(file, "")
	end
	o.validate = function(self, value)
		local ipmasks = {}
		value = clean_text(value)
		string.gsub(value, '[^' .. "\r\n" .. ']+', function(w) table.insert(ipmasks, api.trim(w)) end)
		for index, ipmask in ipairs(ipmasks) do
			if ipmask ~= "" and not ipmask:find("^#") and not ipmask:find("^geoip:") then
				if not ( datatypes.ipmask4(ipmask) or datatypes.ipmask6(ipmask) ) then
					return nil, ipmask .. " " .. translate("Not valid IP format, please re-enter!")
				end
			end
		end
		return value
	end
	return o
end

ru_host_option("ru_proxy_list", "RuProxy",
	translate("Domain list, one per line. Routed according to the RuProxy mode in Basic Settings (Proxy by default)."))
ru_ip_option("ru_proxy_list", "RuProxyIp",
	translate("IPv4/IPv6 address or CIDR list, one per line. Routed according to the RuProxyIp mode in Basic Settings (Proxy by default)."))

ru_host_option("ru_direct_list", "RuDirect",
	translate("Domain list, one per line. Routed according to the RuDirect mode in Basic Settings (Direct by default)."))
ru_ip_option("ru_direct_list", "RuDirectIp",
	translate("IPv4/IPv6 address or CIDR list, one per line. Routed according to the RuDirectIp mode in Basic Settings (Direct by default)."))

---- Direct Hosts
local direct_host = path .. "direct_host"
o = s:taboption("direct_list", TextValue, "direct_host", "", "<font color='red'>" .. translate("Join the direct hosts list of domain names will not proxy.") .. "</font>")
o.rows = 15
o.wrap = "off"
o.cfgvalue = function(self, section)
	return fs.readfile(direct_host) or ""
end
o.write = function(self, section, value)
	fs.writefile(direct_host, value:gsub("\r\n", "\n"))
	sys.call("rm -rf /tmp/etc/passwall_tmp/dns_*")
end
o.remove = function(self, section, value)
	fs.writefile(direct_host, "")
	sys.call("rm -rf /tmp/etc/passwall_tmp/dns_*")
end
o.validate = function(self, value)
	local hosts= {}
	value = clean_text(value)
	string.gsub(value, '[^' .. "\r\n" .. ']+', function(w) table.insert(hosts, api.trim(w)) end)
	for index, host in ipairs(hosts) do
		if host ~= "" and not host:find("^#") and not host:find("^geosite:") then
			if not datatypes.hostname(host) then
				return nil, host .. " " .. translate("Not valid domain name, please re-enter!")
			end
		end
	end
	return value
end

---- Direct IP
local direct_ip = path .. "direct_ip"
o = s:taboption("direct_list", TextValue, "direct_ip", "", "<font color='red'>" .. translate("These had been joined ip addresses will not proxy. Please input the ip address or ip address segment,every line can input only one ip address. For example: 192.168.0.0/24 or 223.5.5.5.") .. "</font>")
o.rows = 15
o.wrap = "off"
o.cfgvalue = function(self, section)
	return fs.readfile(direct_ip) or ""
end
o.write = function(self, section, value)
	fs.writefile(direct_ip, value:gsub("\r\n", "\n"))
end
o.remove = function(self, section, value)
	fs.writefile(direct_ip, "")
end
o.validate = function(self, value)
	local ipmasks= {}
	value = clean_text(value)
	string.gsub(value, '[^' .. "\r\n" .. ']+', function(w) table.insert(ipmasks, api.trim(w)) end)
	for index, ipmask in ipairs(ipmasks) do
		if ipmask ~= "" and not ipmask:find("^#") and not ipmask:find("^geoip:") then
			if not ( datatypes.ipmask4(ipmask) or datatypes.ipmask6(ipmask) ) then
				return nil, ipmask .. " " .. translate("Not valid IP format, please re-enter!")
			end
		end
	end
	return value
end

---- Proxy Hosts
local proxy_host = path .. "proxy_host"
o = s:taboption("proxy_list", TextValue, "proxy_host", "", "<font color='red'>" .. translate("These had been joined websites will use proxy. Please input the domain names of websites, every line can input only one website domain. For example: google.com.") .. "</font>")
o.rows = 15
o.wrap = "off"
o.cfgvalue = function(self, section)
	return fs.readfile(proxy_host) or ""
end
o.write = function(self, section, value)
	fs.writefile(proxy_host, value:gsub("\r\n", "\n"))
	sys.call("rm -rf /tmp/etc/passwall_tmp/dns_*")
end
o.remove = function(self, section, value)
	fs.writefile(proxy_host, "")
	sys.call("rm -rf /tmp/etc/passwall_tmp/dns_*")
end
o.validate = function(self, value)
	local hosts= {}
	value = clean_text(value)
	string.gsub(value, '[^' .. "\r\n" .. ']+', function(w) table.insert(hosts, api.trim(w)) end)
	for index, host in ipairs(hosts) do
		if host ~= "" and not host:find("^#") and not host:find("^geosite:") then
			if not datatypes.hostname(host) then
				return nil, host .. " " .. translate("Not valid domain name, please re-enter!")
			end
		end
	end
	return value
end

---- Proxy IP
local proxy_ip = path .. "proxy_ip"
o = s:taboption("proxy_list", TextValue, "proxy_ip", "", "<font color='red'>" .. translate("These had been joined ip addresses will use proxy. Please input the ip address or ip address segment, every line can input only one ip address. For example: 35.24.0.0/24 or 8.8.4.4.") .. "</font>")
o.rows = 15
o.wrap = "off"
o.cfgvalue = function(self, section)
	return fs.readfile(proxy_ip) or ""
end
o.write = function(self, section, value)
	fs.writefile(proxy_ip, value:gsub("\r\n", "\n"))
end
o.remove = function(self, section, value)
	fs.writefile(proxy_ip, "")
end
o.validate = function(self, value)
	local ipmasks= {}
	value = clean_text(value)
	string.gsub(value, '[^' .. "\r\n" .. ']+', function(w) table.insert(ipmasks, api.trim(w)) end)
	for index, ipmask in ipairs(ipmasks) do
		if ipmask ~= "" and not ipmask:find("^#") and not ipmask:find("^geoip:") then
			if not ( datatypes.ipmask4(ipmask) or datatypes.ipmask6(ipmask) ) then
				return nil, ipmask .. " " .. translate("Not valid IP format, please re-enter!")
			end
		end
	end
	return value
end

---- Block Hosts
local block_host = path .. "block_host"
o = s:taboption("block_list", TextValue, "block_host", "", "<font color='red'>" .. translate("These had been joined websites will be block. Please input the domain names of websites, every line can input only one website domain. For example: twitter.com.") .. "</font>")
o.rows = 15
o.wrap = "off"
o.cfgvalue = function(self, section)
	return fs.readfile(block_host) or ""
end
o.write = function(self, section, value)
	fs.writefile(block_host, value:gsub("\r\n", "\n"))
end
o.remove = function(self, section, value)
	fs.writefile(block_host, "")
end
o.validate = function(self, value)
	local hosts= {}
	value = clean_text(value)
	string.gsub(value, '[^' .. "\r\n" .. ']+', function(w) table.insert(hosts, api.trim(w)) end)
	for index, host in ipairs(hosts) do
		if host ~= "" and not host:find("^#") and not host:find("^geosite:") then
			if not datatypes.hostname(host) then
				return nil, host .. " " .. translate("Not valid domain name, please re-enter!")
			end
		end
	end
	return value
end

---- Block IP
local block_ip = path .. "block_ip"
o = s:taboption("block_list", TextValue, "block_ip", "", "<font color='red'>" .. translate("These had been joined ip addresses will be block. Please input the ip address or ip address segment, every line can input only one ip address.") .. "</font>")
o.rows = 15
o.wrap = "off"
o.cfgvalue = function(self, section)
	return fs.readfile(block_ip) or ""
end
o.write = function(self, section, value)
	fs.writefile(block_ip, value:gsub("\r\n", "\n"))
end
o.remove = function(self, section, value)
	fs.writefile(block_ip, "")
end
o.validate = function(self, value)
	local ipmasks= {}
	value = clean_text(value)
	string.gsub(value, '[^' .. "\r\n" .. ']+', function(w) table.insert(ipmasks, api.trim(w)) end)
	for index, ipmask in ipairs(ipmasks) do
		if ipmask ~= "" and not ipmask:find("^#") and not ipmask:find("^geoip:") then
			if not ( datatypes.ipmask4(ipmask) or datatypes.ipmask6(ipmask) ) then
				return nil, ipmask .. " " .. translate("Not valid IP format, please re-enter!")
			end
		end
	end
	return value
end

---- Lan IPv4
local lanlist_ipv4 = path .. "lanlist_ipv4"
o = s:taboption("lan_ip_list", TextValue, "lanlist_ipv4", "", "<font color='red'>" .. translate("The list is the IPv4 LAN IP list, which represents the direct connection IP of the LAN. If you need the LAN IP in the proxy list, please clear it from the list. Do not modify this list by default.") .. "</font>")
o.rows = 15
o.wrap = "off"
o.cfgvalue = function(self, section)
	return fs.readfile(lanlist_ipv4) or ""
end
o.write = function(self, section, value)
	fs.writefile(lanlist_ipv4, value:gsub("\r\n", "\n"))
end
o.remove = function(self, section, value)
	fs.writefile(lanlist_ipv4, "")
end
o.validate = function(self, value)
	local ipmasks= {}
	value = clean_text(value)
	string.gsub(value, '[^' .. "\r\n" .. ']+', function(w) table.insert(ipmasks, api.trim(w)) end)
	for index, ipmask in ipairs(ipmasks) do
		if ipmask ~= "" and not ipmask:find("^#") then
			if not datatypes.ipmask4(ipmask) then
				return nil, ipmask .. " " .. translate("Not valid IPv4 format, please re-enter!")
			end
		end
	end
	return value
end

---- Lan IPv6
local lanlist_ipv6 = path .. "lanlist_ipv6"
o = s:taboption("lan_ip_list", TextValue, "lanlist_ipv6", "", "<font color='red'>" .. translate("The list is the IPv6 LAN IP list, which represents the direct connection IP of the LAN. If you need the LAN IP in the proxy list, please clear it from the list. Do not modify this list by default.") .. "</font>")
o.rows = 15
o.wrap = "off"
o.cfgvalue = function(self, section)
	return fs.readfile(lanlist_ipv6) or ""
end
o.write = function(self, section, value)
	fs.writefile(lanlist_ipv6, value:gsub("\r\n", "\n"))
end
o.remove = function(self, section, value)
	fs.writefile(lanlist_ipv6, "")
end
o.validate = function(self, value)
	local ipmasks= {}
	value = clean_text(value)
	string.gsub(value, '[^' .. "\r\n" .. ']+', function(w) table.insert(ipmasks, api.trim(w)) end)
	for index, ipmask in ipairs(ipmasks) do
		if ipmask ~= "" and not ipmask:find("^#") then
			if not datatypes.ipmask6(ipmask) then
				return nil, ipmask .. " " .. translate("Not valid IPv6 format, please re-enter!")
			end
		end
	end
	return value
end

---- Route Hosts
local hosts = "/etc/hosts"
o = s:taboption("route_hosts", TextValue, "hosts", "", "<font color='red'>" .. translate("Configure routing etc/hosts file, if you don't know what you are doing, please don't change the content.") .. "</font>")
o.rows = 15
o.wrap = "off"
o.cfgvalue = function(self, section)
	return fs.readfile(hosts) or ""
end
o.write = function(self, section, value)
	fs.writefile(hosts, clean_text(value))
end
o.remove = function(self, section, value)
	fs.writefile(hosts, "")
end

local geo_dir = (api.uci_get_c("@global_rules[0]", "v2ray_location_asset") or "/usr/share/v2ray/"):match("^(.*)/")
local geosite_path = geo_dir .. "/geosite.dat"
local geoip_path = geo_dir .. "/geoip.dat"
if api.finded_com("geoview") and fs.access(geosite_path) and fs.access(geoip_path) then
	if api.compare_versions(api.get_app_version("geoview"), ">=", "0.1.0") then
		s:tab("geoview", translate("Geo View"))
		o = s:taboption("geoview", DummyValue, "_geoview_fieldset")
		o.rawhtml = true
		o.template = m:template_path("/rule_list/geoview")
	end
end

m.on_before_save = function(self)
	m:set("@global[0]", "flush_set", "1")
end

return api.return_map(m)
