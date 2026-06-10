#!/usr/bin/env bash
set -eux
USE_DEBIAN=
PROJECT_DIR=$(pwd)
IMAGE=${PROJECT_DIR}/image/buildroot/output/images/rootfs.ext2
if [[ -n "${USE_DEBIAN}" ]]; then
  IMAGE=${PROJECT_DIR}/image/trixie.img
fi
cat <<EOF >syzkaller/manager.cfg
{
    "target": "linux/amd64",
    "http": "0.0.0.0:56741",
    "workdir": "${PROJECT_DIR}/syzkaller/workdir",
    "kernel_obj": "${PROJECT_DIR}/linux",
    "image": "${IMAGE}",
    "sshkey": "${PROJECT_DIR}/image/trixie.id_rsa",
    "syzkaller": "${PROJECT_DIR}/syzkaller",
    "procs": 4,
    "type": "qemu",
    "enable_syscalls": [
        "ictra_uaf",
        "ictra_heap_oob",
        "ictra_static_oob",
        "open",
        "openat",
        "read",
        "write",
        "readv",
        "writev",
        "pread64",
        "pwrite64",
        "socket",
        "setsockopt",
        "openat\$dvkm",
        "ioctl\$DVKM_INTEGER_OVERFLOW",
        "ioctl\$DVKM_INTEGER_UNDERFLOW",
        "ioctl\$DVKM_STACK_BUFFER_OVERFLOW",
        "ioctl\$DVKM_HEAP_BUFFER_OVERFLOW",
        "ioctl\$DVKM_STACK_OOBR",
        "ioctl\$DVKM_STACK_OOBW",
        "ioctl\$DVKM_HEAP_OOBR",
        "ioctl\$DVKM_HEAP_OOBW",
        "ioctl\$DVKM_USE_AFTER_FREE",
        "ioctl\$DVKM_DOUBLE_FREE"
    ],
    "vm": {
        "count": ${VM_COUNT:-8},
        "kernel": "${PROJECT_DIR}/linux/arch/x86/boot/bzImage",
        "cmdline": "net.ifnames=0 root=/dev/sda console=ttyS0 selinux=0 mitigations=off panic=1",
        "cpu": 2,
        "mem": 2048
    }
}
EOF

mkdir -p syzkaller/workdir
echo "Starting syz-manager with buildroot image..."
./syzkaller/bin/syz-manager -config=${PROJECT_DIR}/syzkaller/manager.cfg
