#!/usr/bin/env bash
set -eux

cd linux
make defconfig
make kvm_guest.config

./scripts/config --enable CONFIG_KASAN
./scripts/config --enable CONFIG_KASAN_INLINE
./scripts/config --enable CONFIG_UBSAN
./scripts/config --enable CONFIG_KASAN_GENERIC
./scripts/config --enable CONFIG_KCOV
./scripts/config --enable CONFIG_KCOV_ENABLE_COMPARISONS
./scripts/config --enable CONFIG_DEBUG_INFO
./scripts/config --enable CONFIG_DEBUG_INFO_DWARF4
./scripts/config --enable CONFIG_CONFIGFS_FS
./scripts/config --enable CONFIG_SECURITYFS
make olddefconfig
make -j$(nproc)
cd ..
