#!/usr/bin/env bash
set -eux

IMAGE="${1:-./image/buildroot/output/images/rootfs.ext2}"
SSH_PUBKEY="${2:-./image/trixie.id_rsa.pub}"

if [ ! -f "$IMAGE" ]; then
  echo "Error: Buildroot image not found at $IMAGE"
  exit 1
fi

if [ ! -f "$SSH_PUBKEY" ]; then
  echo "Error: SSH public key not found at $SSH_PUBKEY"
  exit 1
fi

# Create a temp inittab with sysfs and debugfs mounts
INITTAB=$(mktemp)
cat >"$INITTAB" <<'INITTAB'
# /etc/inittab

# Startup the system
::sysinit:/bin/mount -t proc proc /proc
::sysinit:/bin/mount -o remount,rw /
::sysinit:/bin/mkdir -p /dev/pts /dev/shm
::sysinit:/bin/mount -a
::sysinit:/bin/mount -t sysfs none /sys
::sysinit:/bin/mount -t debugfs none /sys/kernel/debug
::sysinit:/bin/mkdir -p /run/lock/subsys
::sysinit:/sbin/swapon -a
null::sysinit:/bin/ln -sf /proc/self/fd /dev/fd
null::sysinit:/bin/ln -sf /proc/self/fd/0 /dev/stdin
null::sysinit:/bin/ln -sf /proc/self/fd/1 /dev/stdout
null::sysinit:/bin/ln -sf /proc/self/fd/2 /dev/stderr
::sysinit:/bin/hostname -F /etc/hostname
::sysinit:/etc/init.d/rcS

# Put a getty on the serial port
console::respawn:/sbin/getty -L  console 0 vt100 # GENERIC_SERIAL
tty1::respawn:/sbin/getty -L  tty1 0 vt100 # QEMU graphical window

# Stuff to do before rebooting
::shutdown:/etc/init.d/rcK
::shutdown:/sbin/swapoff -a
::shutdown:/bin/umount -a -r
INITTAB

debugfs -w -R "rm /etc/inittab" "$IMAGE" 2>/dev/null || true
debugfs -w -R "write $INITTAB /etc/inittab" "$IMAGE"
rm -f "$INITTAB"

# Inject SSH public key for root
SSH_DIR=$(mktemp -d)
mkdir -p "$SSH_DIR/.ssh"
cp "$SSH_PUBKEY" "$SSH_DIR/.ssh/authorized_keys"
chmod 700 "$SSH_DIR/.ssh"
chmod 600 "$SSH_DIR/.ssh/authorized_keys"

debugfs -w -R "mkdir /root/.ssh" "$IMAGE" 2>/dev/null || true
debugfs -w -R "write $SSH_DIR/.ssh/authorized_keys /root/.ssh/authorized_keys" "$IMAGE"
debugfs -w -R "set_inode_field /root/.ssh mode 040700" "$IMAGE" 2>/dev/null || true
debugfs -w -R "set_inode_field /root/.ssh/authorized_keys mode 0100600" "$IMAGE" 2>/dev/null || true
rm -rf "$SSH_DIR"

echo "Verifying inittab..."
debugfs -R "cat /etc/inittab" "$IMAGE" 2>/dev/null | grep -E "sysfs|debugfs" || {
  echo "ERROR: sysfs/debugfs mounts not found in patched inittab"
  exit 1
}

echo "Verifying authorized_keys..."
debugfs -R "cat /root/.ssh/authorized_keys" "$IMAGE" 2>/dev/null | grep -E "ssh-rsa|ssh-ed25519" || {
  echo "ERROR: SSH public key not found in /root/.ssh/authorized_keys"
  exit 1
}

# Generate SSH host keys and configure sshd
HOST_KEY_DIR=$(mktemp -d)
ssh-keygen -t rsa -f "${HOST_KEY_DIR}/ssh_host_rsa_key" -N "" -q
ssh-keygen -t ecdsa -f "${HOST_KEY_DIR}/ssh_host_ecdsa_key" -N "" -q
ssh-keygen -t ed25519 -f "${HOST_KEY_DIR}/ssh_host_ed25519_key" -N "" -q

debugfs -w -R "rm /etc/ssh/ssh_host_rsa_key" "$IMAGE" 2>/dev/null || true
debugfs -w -R "rm /etc/ssh/ssh_host_ecdsa_key" "$IMAGE" 2>/dev/null || true
debugfs -w -R "rm /etc/ssh/ssh_host_ed25519_key" "$IMAGE" 2>/dev/null || true
debugfs -w -R "write ${HOST_KEY_DIR}/ssh_host_rsa_key /etc/ssh/ssh_host_rsa_key" "$IMAGE"
debugfs -w -R "write ${HOST_KEY_DIR}/ssh_host_ecdsa_key /etc/ssh/ssh_host_ecdsa_key" "$IMAGE"
debugfs -w -R "write ${HOST_KEY_DIR}/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key" "$IMAGE"
debugfs -w -R "set_inode_field /etc/ssh/ssh_host_rsa_key mode 0100600" "$IMAGE" 2>/dev/null || true
debugfs -w -R "set_inode_field /etc/ssh/ssh_host_ecdsa_key mode 0100600" "$IMAGE" 2>/dev/null || true
debugfs -w -R "set_inode_field /etc/ssh/ssh_host_ed25519_key mode 0100600" "$IMAGE" 2>/dev/null || true
rm -rf "$HOST_KEY_DIR"

# Override sshd_config with syzkaller-compatible config
SSHD_CONFIG=$(mktemp)
cat >"$SSHD_CONFIG" <<'SSHD'
PermitRootLogin yes
PasswordAuthentication yes
PermitEmptyPasswords yes
ClientAliveInterval 420
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
Subsystem sftp /usr/libexec/sftp-server
SSHD

debugfs -w -R "rm /etc/ssh/sshd_config" "$IMAGE" 2>/dev/null || true
debugfs -w -R "write $SSHD_CONFIG /etc/ssh/sshd_config" "$IMAGE"
rm -f "$SSHD_CONFIG"

echo "Buildroot image patched successfully: $IMAGE"
