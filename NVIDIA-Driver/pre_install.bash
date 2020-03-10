#!/usr/bin/env bash

# Make sure to have root privilege
if [ "$(whoami)" != 'root' ]; then
  echo -e "\e[31m\xe2\x9d\x8c Please retry with root privilege.\e[m"
  exit 1
fi

# Make sure `IOMMU` is disabled for Intel CPUs
if grep -q 'Intel' /proc/cpuinfo; then
  echo -e "\e[33m\xe2\x8f\xb3 Found \e[32mIntel CPU(s)\e[33m, disabling IOMMU ...\e[m"
  if [ ! -d /etc/kernel/cmdline-removal.d ]; then
    mkdir -p /etc/kernel/cmdline-removal.d
  fi
  cat <<< 'intel_iommu=igfx_off' > /etc/kernel/cmdline-removal.d/intel-iommu.conf
fi

# Create a systemd unit that overwrites `libGL` library after every OS update
echo -e "\e[33m\xe2\x8f\xb3 Creating a systemd unit that fix problems with \"libGL\" library ...\
\e[m"

## Write the systemd file at "/etc/systemd/system/fix-nvidia-libGL-trigger.service"
echo -e "\e[33m Writing the systemd unit file at \"\e[32m\
/etc/systemd/system/fix-nvidia-libGL-trigger.service\e[33m\"\e[m"

cat <<EOF > /etc/systemd/system/fix-nvidia-libGL-trigger.service
[Unit]
Description=Fixes libGL symlinks for the NVIDIA proprietary driver
BindsTo=update-triggers.target

[Service]
Type=oneshot
ExecStart=/usr/bin/ln -sfv /opt/nvidia/lib/libGL.so.1 /usr/lib/libGL.so.1
ExecStart=/usr/bin/ln -sfv /opt/nvidia/lib32/libGL.so.1 /usr/lib32/libGL.so.1
EOF

## Reload systemd daemon to find the new service
echo -e "\e[33m Reload systemd manager configuration to pick up the new service ...\e[m"
systemctl daemon-reload

## Make sure the service is launched after every OS update
echo -e "\e[33m Creating a hook to Clear Linux OS updates ...\e[m"
systemctl add-wants update-triggers.target fix-nvidia-libGL-trigger.service

# Install Dynamic Kernel Module System (DKMS) if not found, according to kernel variant
VARIANT="$(uname -r)" && VARIANT=${VARIANT##*.}
case "$VARIANT" in
  native|lts)
    if ! swupd bundle-list | grep -q kernel-"$VARIANT"-dkms; then
      echo -e "\e[33m\xe2\x8f\xb3 Installing Dynamic Kernel Module System ...\e[m"
      swupd bundle-add kernel-"$VARIANT"-dkms
    fi
    ;;
  *)
    echo -e "\e[31m\xe2\x9d\x8c The kernel must be either \"\e[32mnative\e[31m\" or \"\e[32mlts\
\e[31m\".\e[m"
    exit 1
    ;;
esac

## Update Clear Linux OS bootloader
echo -e "\e[33m\xe2\x8f\xb3 Updating Clear Linux OS bootloader ...\e[m"
clr-boot-manager update

# Disable nouveau driver
echo -e "\e[33m\xe2\x8f\xb3 Disabling nouveau Driver ...\e[m"
if [ ! -d /etc/modprobe.d ]; then
  mkdir /etc/modprobe.d
fi
cat <<EOF > /etc/modprobe.d/disable-nouveau.conf
blacklist nouveau
options nouveau modeset=0
EOF

# Ask the user whether he wants to reboot now
echo -e "\e[32m Please reboot your system ASAP and execute the \e[33minstall.bash \e[32mscript to \
install the NVIDIA proprietary driver.\e[m"
exit 0