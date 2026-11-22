#!/bin/bash
# ============================================================
# BE6500 v4 额外插件源 (2026-11-21)
# 本文件是 OpenWRT-CI 的 Scripts/PRIVATE.sh，Packages.sh 末尾会 source 它，
# 可直接调用 Packages.sh 里定义的 UPDATE_PACKAGE 函数。
# Nikki 不在此列：Packages.sh 已自带 UPDATE_PACKAGE "nikki" "nikkinikki-org/OpenWrt-nikki" "main"
# ============================================================

# Honk：预编译打包（上游 honk-core release 资产、哈希校验），CI 免 zig 工具链
UPDATE_PACKAGE "honk" "189160/luci-app-honk" "main"

# oaf 应用过滤：官方 OpenAppFilter（写法照 Packages.sh 注释里的官方示例）
UPDATE_PACKAGE "OpenAppFilter" "destan19/OpenAppFilter" "master" "" "open-app-filter luci-app-appfilter"

# bandix 流量监控：核心 + LuCI
UPDATE_PACKAGE "bandix" "timsaya/openwrt-bandix" "main"
UPDATE_PACKAGE "luci-app-bandix" "timsaya/luci-app-bandix" "main"

# Lucky 的 LuCI 界面（lucky 本体已在 immortalwrt 官方 packages 源里，只加界面）
UPDATE_PACKAGE "luci-app-lucky" "gdy666/luci-app-lucky" "main"
