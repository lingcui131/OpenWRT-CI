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

# ============================================================
# 2026-11-23 BTF 修复（源码层兜底）：上一版成品内核无 BTF（/sys/kernel/btf 不存在、honk 崩溃循环），
# .config 层已在 PRIVATE.txt 补全依赖链，这里再直接给内核配置片段钉一遍；
# 同时关掉这台 eMMC 机型用不上的大块功能，给 BTF 腾 7168k 内核分区空间
# （本地 Kwrt 版实测口径：io_uring/ftrace/NAND·NOR·UBI 合计约省 1.3MB，honk 与全部插件不依赖它们）
# ============================================================
KCFGS=""
for root in "$PWD" /mnt/build_wrt; do
  [ -d "$root/target/linux/qualcommbe" ] || continue
  for f in $(find "$root/target/linux/qualcommbe" -name 'config-6.18' 2>/dev/null); do
    case " $KCFGS " in *" $f "*) ;; *) KCFGS="$KCFGS $f" ;; esac
  done
done
if [ -n "$KCFGS" ]; then
  for KCFG in $KCFGS; do
    {
      echo 'CONFIG_DEBUG_INFO=y'
      echo 'CONFIG_DEBUG_INFO_BTF=y'
      echo '# CONFIG_DEBUG_INFO_REDUCED is not set'
      echo '# CONFIG_MTD_NAND_QCOM is not set'
      echo '# CONFIG_SPI_QPIC_SNAND is not set'
      echo '# CONFIG_MTD_SPI_NAND is not set'
      echo '# CONFIG_MTD_RAW_NAND is not set'
      echo '# CONFIG_MTD_NAND_CORE is not set'
      echo '# CONFIG_MTD_SPI_NOR is not set'
      echo '# CONFIG_MTD_UBI is not set'
      echo '# CONFIG_MTD_UBI_BLOCK is not set'
      echo '# CONFIG_UBIFS_FS is not set'
      echo '# CONFIG_DEBUG_FS is not set'
    } >> "$KCFG"
    echo "BTF fix: patched kernel fragment $KCFG (verify: $(grep -c 'CONFIG_DEBUG_INFO_BTF=y' "$KCFG") BTF lines, tail:)"
    tail -n 3 "$KCFG"
  done
else
  echo "BTF fix: kernel fragment config-6.18 not found, skipped"
fi

# ============================================================
# 2026-11-23 主题源：kucat 主题 + argon 配置插件（官方仓库拉取）
# ============================================================
UPDATE_PACKAGE "luci-theme-kucat" "sirpdboy/luci-theme-kucat" "master"
UPDATE_PACKAGE "luci-app-argon-config" "jerrykuku/luci-app-argon-config" "master"

# 默认主题设为 argon（files 覆盖层 uci-defaults，首次启动生效；之后可在 LuCI 里切 kucat 对比）
if [ -d package ] && [ -d target ]; then
  mkdir -p files/etc/uci-defaults
  printf '%s\n' "uci set luci.main.mediaurlbase='/luci-static/argon'" "uci commit luci" "exit 0" > files/etc/uci-defaults/99-luci-theme
  echo "theme: default set to argon via uci-defaults"
fi

# ============================================================
# 2026-11-24 第五档：RE-CS-06 内核镜像压缩 gzip → lzma
# 前四档砍配置实际只省 56KB（NAND 栈被 Kconfig 依赖拉回），还差 358,120 字节；
# 源码 target/linux/qualcommbe/image/Makefile 现成有 Device/FitImageLzma 模板，
# 把 jdcloud_re-cs-06 的镜像配方改过去，靠压缩率一次补满，不砍任何功能。
# ============================================================
IMG_MK=""
for root in "$PWD" /mnt/build_wrt; do
  if [ -f "$root/target/linux/qualcommbe/image/ipq53xx.mk" ]; then
    IMG_MK="$root/target/linux/qualcommbe/image/ipq53xx.mk"
    break
  fi
done
if [ -n "$IMG_MK" ]; then
  sed -i '/^define Device\/jdcloud_re-cs-06/,/^endef$/ s/Device\/FitImage)/Device\/FitImageLzma)/' "$IMG_MK"
  echo "LZMA fix: jdcloud_re-cs-06 image recipe now:"
  sed -n '/^define Device\/jdcloud_re-cs-06/,/^endef$/p' "$IMG_MK" | grep 'FitImage'
else
  echo "LZMA fix: ipq53xx.mk not found, skipped"
fi
