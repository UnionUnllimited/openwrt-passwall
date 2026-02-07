# OpenWrt PassWall (русский форк)

Этот форк ориентирован на использование вне китайского региона:

- убраны пункты, связанные с ChinaDNS/China List и их обновлениями в интерфейсе;
- отключена конфигурация Xray Balancing в LuCI;
- URLTest для Sing-box теперь настраивается по группам, а не по отдельным нодам;
- расширен список доменов для проверок доступности в тестах.

## Сборка в OpenWrt buildroot

Ниже пример минимального процесса сборки в OpenWrt buildroot:

1. Добавьте feed этого форка в `feeds.conf.default`:

```text
src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main
src-git passwall_luci https://github.com/<ваш-аккаунт>/openwrt-passwall.git;main
```

2. Обновите feeds и установите пакеты:

```sh
./scripts/feeds update -a
./scripts/feeds install -a
```

3. Включите нужные пакеты в `menuconfig`, например:

```sh
make menuconfig
# LuCI -> Applications -> luci-app-passwall
```

4. Соберите пакеты:

```sh
make package/luci-app-passwall/compile V=s
```

## Установка форка на роутер

После сборки IPK можно установить на роутер:

```sh
opkg install /tmp/luci-app-passwall_*.ipk
```

Если вы используете собственный репозиторий, разместите пакеты в нём и установите через `opkg`.
