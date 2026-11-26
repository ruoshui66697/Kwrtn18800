#!/bin/bash

shopt -s extglob

SHELL_FOLDER=$(dirname $(readlink -f "$0"))

#bash $SHELL_FOLDER/../common/kernel_6.1.sh

sed -i 's/DEFAULT_PACKAGES +=/DEFAULT_PACKAGES += fdisk lsblk kmod-usb-net-asix-ax88179 kmod-usb-net-rtl8152 kmod-rtl8189es luci-app-diskman automount/' target/linux/sunxi/Makefile

# 英菲克 i9（A31s）：往 sunxi 板型清单追加一个 Device
# 两种 sunxi 目录命名都兼容
IMG_MK=target/linux/sunxi/image/cortex-a7.mk
[ -f "$IMG_MK" ] || IMG_MK=target/linux/sunxi/image/cortexa7.mk

# 设备名最后一段必须是 sina31s：OpenWrt 用「SoC 名 + 设备名最后一段」
# 拼出 DTS 文件名，正好得到 sun6i-a31s-sina31s.dtb，无需另放 DTS 文件
if ! grep -q 'define Device/infik_sina31s' "$IMG_MK"; then
cat >> "$IMG_MK" <<'EOF'

define Device/infik_sina31s
  DEVICE_VENDOR := Infik
  DEVICE_MODEL := i9
  DEVICE_VARIANT := A31s-USB
  SOC := sun6i-a31s
  DEVICE_PACKAGES := \
	kmod-usb-core kmod-usb-ohci kmod-usb-ehci kmod-usb-storage \
	kmod-scsi-core kmod-fs-ext4 kmod-fs-vfat \
	kmod-nls-base kmod-nls-cp437 kmod-nls-iso8859-1
endef
TARGET_DEVICES += infik_sina31s
EOF
fi

# 给这个设备绑一份 U-Boot：让打包脚本能拿到
# $(DEVICE_NAME)-u-boot-with-spl.bin 和 $(DEVICE_NAME)-boot.scr
# 复用主线 Sinlinx_SinA31s_defconfig，bin 不再需要从本机上传
python3 - <<'PY'
p = "package/boot/uboot-sunxi/Makefile"
s = open(p).read()
block = """define U-Boot/Sinlinx_SinA31s
  BUILD_SUBTARGET:=cortexa7
  NAME:=Infik i9 (A31s)
  BUILD_DEVICES:=infik_sina31s
endef

UBOOT_TARGETS += Sinlinx_SinA31s

"""
anchor = "$(eval $(call BuildPackage/U-Boot))"
if "U-Boot/Sinlinx_SinA31s" not in s and anchor in s:
    open(p, "w").write(s.replace(anchor, block + anchor))
PY

# 在 .config 里选中新板型（此脚本跑在 make defconfig 之前）
if ! grep -q 'CONFIG_TARGET_DEVICE_sunxi_cortexa7_DEVICE_infik_sina31s' .config; then
  echo "CONFIG_TARGET_DEVICE_sunxi_cortexa7_DEVICE_infik_sina31s=y" >> .config
fi

# 刷新时间戳，保证 defconfig 重新扫描板型清单
touch "$IMG_MK" target/linux/sunxi/Makefile
