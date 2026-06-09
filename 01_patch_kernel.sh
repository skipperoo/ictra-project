#!/usr/bin/env bash
set -eux

cat <<'EOF' >>linux/kernel/sys.c

SYSCALL_DEFINE2(ictra_uaf, unsigned long, cmd, unsigned long, val)
{
    char *ptr;
    if (cmd != 0xCAFECAFE || val != 0xDEADBEEF)
        return -EINVAL;

    ptr = kmalloc(16, GFP_KERNEL);
    if (!ptr)
        return -ENOMEM;

    kfree(ptr);
    ptr[0] = 'A';
    return 0;
}

SYSCALL_DEFINE2(ictra_heap_oob, unsigned long, cmd, unsigned long, size)
{
    char *ptr;
    if (cmd != 0xBAADF00D)
        return -EINVAL;

    ptr = kmalloc(16, GFP_KERNEL);
    if (!ptr)
        return -ENOMEM;

    if (size <= 32) {
        memset(ptr, 'B', size);
    }

    kfree(ptr);
    return 0;
}

static char global_buffer[16];
SYSCALL_DEFINE2(ictra_static_oob, unsigned long, cmd, unsigned long, index)
{
    if (cmd != 0xFEEDFACE)
        return -EINVAL;

    global_buffer[index] = 'C';
    return 0;
}
EOF

sed -i '/#endif \/\* _LINUX_SYSCALLS_H \*\//i asmlinkage long sys_ictra_uaf(unsigned long cmd, unsigned long val);\nasmlinkage long sys_ictra_heap_oob(unsigned long cmd, unsigned long size);\nasmlinkage long sys_ictra_static_oob(unsigned long cmd, unsigned long index);' linux/include/linux/syscalls.h

LAST_SYS=$(awk '/common/ {print $1}' linux/arch/x86/entry/syscalls/syscall_64.tbl | tail -n 1)
NEXT_SYS=$((LAST_SYS + 1))
echo -e "${NEXT_SYS}\tcommon\tictra_uaf\tsys_ictra_uaf" >>linux/arch/x86/entry/syscalls/syscall_64.tbl
NEXT_SYS=$((NEXT_SYS + 1))
echo -e "${NEXT_SYS}\tcommon\tictra_heap_oob\tsys_ictra_heap_oob" >>linux/arch/x86/entry/syscalls/syscall_64.tbl
NEXT_SYS=$((NEXT_SYS + 1))
echo -e "${NEXT_SYS}\tcommon\tictra_static_oob\tsys_ictra_static_oob" >>linux/arch/x86/entry/syscalls/syscall_64.tbl
