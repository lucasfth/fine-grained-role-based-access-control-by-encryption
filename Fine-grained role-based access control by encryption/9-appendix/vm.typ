#figure(
  kind: "listing",
  supplement: "Listing",
  scope: "parent",
  placement: bottom,
  block(
    width: 100%,
    align(left,
```bash
root@ubuntu-s-1vcpu-1gb-35gb-intel-fra1:~# inxi -Fxz
System:
  Kernel: 6.8.0-111-generic arch: x86_64 bits: 64 compiler: gcc v: 13.3.0
  Console: pty pts/6 Distro: Ubuntu 24.04.4 LTS (Noble Numbat)
Machine:
  Type: Kvm Mobo: DigitalOcean model: Droplet v: 20171212 serial: <filter> BIOS: DigitalOcean
    v: 20171212 date: 12/12/2017
CPU:
  Info: 8-core model: DO-Premium-AMD bits: 64 type: MCP arch: Zen 2 rev: 0 cache: L1: 512 KiB
    L2: 4 MiB L3: 16 MiB
  Speed (MHz): avg: 1996 min/max: N/A cores: 1: 1996 2: 1996 3: 1996 4: 1996 5: 1996 6: 1996
    7: 1996 8: 1996 bogomips: 31940
  Flags: avx avx2 ht lm nx pae sse sse2 sse3 sse4_1 sse4_2 sse4a ssse3 svm
Graphics:
  Device-1: Red Hat Virtio 1.0 GPU driver: virtio-pci v: 1 bus-ID: 00:02.0
  Display: server: No display server data found. Headless machine? tty: 110x29
    resolution: 1024x768
  API: EGL v: 1.5 drivers: kms_swrast,swrast platforms: active: gbm,surfaceless,device
    inactive: wayland,x11
  API: OpenGL v: 4.5 vendor: mesa v: 25.2.8-0ubuntu0.24.04.1 note: console (EGL sourced)
    renderer: llvmpipe (LLVM 20.1.2 256 bits)
Audio:
  Message: No device data found.
  API: ALSA v: k6.8.0-111-generic status: inactive
Network:
  Device-1: Intel 82371AB/EB/MB PIIX4 ACPI vendor: Red Hat Qemu virtual machine
    type: network bridge driver: N/A port: N/A bus-ID: 00:01.3
  Device-2: Red Hat Virtio network driver: virtio-pci v: 1 port: c1a0 bus-ID: 00:03.0
  IF: eth0 state: up speed: -1 duplex: unknown mac: <filter>
  Device-3: Red Hat Virtio network driver: virtio-pci v: 1 port: c1c0 bus-ID: 00:04.0
  IF: eth1 state: up speed: -1 duplex: unknown mac: <filter>
  IF-ID-1: br-cf3f443f079d state: down mac: <filter>
  IF-ID-2: docker0 state: down mac: <filter>
Drives:
  Local Storage: total: 320 GiB used: 19.4 GiB (6.1%)
  ID-1: /dev/vda model: N/A size: 320 GiB
  ID-2: /dev/vdb model: N/A size: 488 KiB
Partition:
  ID-1: / size: 308.93 GiB used: 19.28 GiB (6.2%) fs: ext4 dev: /dev/vda1
  ID-2: /boot size: 880.4 MiB used: 113.9 MiB (12.9%) fs: ext4 dev: /dev/vda16
  ID-3: /boot/efi size: 104.3 MiB used: 6.1 MiB (5.9%) fs: vfat dev: /dev/vda15
Swap:
  Alert: No swap data was found.
Sensors:
  Src: lm-sensors+/sys Message: No sensor data found using /sys/class/hwmon or lm-sensors.
Info:
  Memory: total: 16 GiB available: 15.62 GiB used: 1.03 GiB (6.6%)
  Processes: 180 Uptime: 4d 1h 2m Init: systemd target: graphical (5)
  Packages: 813 Compilers: N/A Shell: Bash v: 5.2.21 inxi: 3.3.34
```
    )
  ),
  caption: [VM specification used for the benchmarks of OSWS]
)<lst:vm-spec>
