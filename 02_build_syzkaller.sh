#!/usr/bin/env bash
set -eux

cat >syzkaller/sys/linux/ictra_uaf.txt <<'TXT'
include <linux/syscalls.h>
ictra_uaf(cmd intptr, val intptr)
TXT
cat >syzkaller/sys/linux/ictra_uaf_amd64.const <<'CONST'
# env: arch=amd64
__NR_ictra_uaf = 472
CONST

cat >syzkaller/sys/linux/ictra_heap_oob.txt <<'TXT'
include <linux/syscalls.h>
ictra_heap_oob(cmd intptr, size intptr)
TXT
cat >syzkaller/sys/linux/ictra_heap_oob_amd64.const <<'CONST'
# env: arch=amd64
__NR_ictra_heap_oob = 473
CONST

cat >syzkaller/sys/linux/ictra_static_oob.txt <<'TXT'
include <linux/syscalls.h>
ictra_static_oob(cmd intptr, index intptr)
TXT
cat >syzkaller/sys/linux/ictra_static_oob_amd64.const <<'CONST'
# env: arch=amd64
__NR_ictra_static_oob = 474
CONST

cat dvkm.txt >syzkaller/sys/linux/dvkm.txt

cd syzkaller
CI=1 ./tools/syz-env make generate
CI=1 ./tools/syz-env make -j$(nproc)
cd ..
