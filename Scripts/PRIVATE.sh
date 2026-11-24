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

# ============================================================
# 2026-11-24 第六档：Honk 启动可靠性 + Doona 面板随固件内置 + geo 软链
# 真机日志实证的三处缺陷：
# 1) native_api.ui 指向的目录不存在时 honk-core 直接崩溃循环
#    （failed to inspect native UI directory），新刷机没面板目录必中；
#    且面板在线更新在国内网络拉不动 GitHub。把与 honk v0.1.0-beta.6
#    配套的 doona v0.1.0-rc.6（程序+字体）预置进固件：开机即有面板，
#    也不再因缺目录崩溃。CI 网络可直达 GitHub。
# 2) v2ray-geoip/geosite 的 dat 装在 /usr/share/v2ray；再在
#    /usr/share/honk 建软链兜底，两种查找路径都满足。
# 3) honk.init 的 term_timeout 只有 8s：eBPF 卸载与连接排空经常超过
#    8s，procd 会 SIGKILL 正在关闭的实例，残留的 datapath 锁让下一次
#    启动长时间等待甚至失败（前台日志实测等待锁）。放宽到 60s。
# ============================================================
if [ -d package ] && [ -d target ]; then
  DOONA_TAG="v0.1.0-rc.6"
  DOONA_DIR="files/usr/share/honk/doona"
  mkdir -p "$DOONA_DIR"
  for f in "doona-0.1.0-rc.6.tar.gz" "doona-fonts-0.1.0-rc.6.tar.gz"; do
    if curl -fsSL --retry 3 -o "/tmp/$f" "https://github.com/Zakkaus/doona/releases/download/$DOONA_TAG/$f"; then
      tar -xzf "/tmp/$f" -C "$DOONA_DIR" && echo "DOONA fix: $f installed"
    else
      echo "DOONA fix: download $f FAILED"
    fi
  done
  if [ -f "$DOONA_DIR/index.html" ]; then
    printf '{"version":"0.1.0-rc.6","tag":"v0.1.0-rc.6","installed_at":"ci-build"}\n' > "$DOONA_DIR/.honk-panel.json"
    echo "DOONA fix: panel ready at /usr/share/honk/doona"
  else
    echo "DOONA fix: index.html missing, panel NOT installed"
  fi
  ln -sf /usr/share/v2ray/geoip.dat files/usr/share/honk/geoip.dat
  ln -sf /usr/share/v2ray/geosite.dat files/usr/share/honk/geosite.dat
  echo "GEO fix: symlinks created in /usr/share/honk"
  HONK_INIT=$(find package -path '*honk*' -name 'honk.init' | head -n 1)
  if [ -n "$HONK_INIT" ]; then
    sed -i 's/term_timeout 8/term_timeout 60/' "$HONK_INIT"
    echo "HONK init fix: $(grep -o 'term_timeout [0-9]*' "$HONK_INIT" | head -n 1)"
  else
    echo "HONK init fix: honk.init not found, skipped"
  fi
fi

# ============================================================
# 2026-11-24 第七档：Honk 核心变体 -native-api（精简）→ -full（全功能）
# 189160 包默认下 daeuniverse/honk 同 release 的 -native-api 变体
# （features: ebpf,rprx,native-api,jemalloc —— 无 native-ui、无 clash-api），
# 所以 ui: embedded 必然报错、config_write 不被识别。改下 -full 变体
# （同为 jemalloc 系，含 native-ui + clash-api），embedded 面板、
# config_write、password_auth 均可用。哈希取自上游 release 资产 digest，
# 已用现 -native-api 的 aarch64 哈希交叉核对、同源一致。
# ============================================================
HONK_MK=$(find package -path '*/honk/Makefile' | head -n 1)
if [ -n "$HONK_MK" ]; then
  sed -i 's/^HONK_VARIANT:=.*/HONK_VARIANT:=-full/' "$HONK_MK"
  sed -i 's/^HONK_HASH_AARCH64:=.*/HONK_HASH_AARCH64:=5e4c0359950e0f19fac53e31ef9ffbe9f0aafca92331c3fa81e5b56212950a6e/' "$HONK_MK"
  sed -i 's/^HONK_HASH_X86_64:=.*/HONK_HASH_X86_64:=2783b8f0856fc1aecd1cd1d911d9a904c593cd507cf61e5fa24fbd7075317244/' "$HONK_MK"
  echo "HONK variant fix: $(grep '^HONK_VARIANT' "$HONK_MK")"
else
  echo "HONK variant fix: honk/Makefile not found, skipped"
fi
