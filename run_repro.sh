#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
CRASHES_DIR=${1:-"${PROJECT_DIR}/syzkaller/workdir/crashes"}

mapfile -t REPROS < <(find "$CRASHES_DIR" -name 'repro.cprog' 2>/dev/null | sort)

if [ ${#REPROS[@]} -eq 0 ]; then
  echo "No repro.cprog files found in $CRASHES_DIR..."
  exit 1
fi

echo "Available reproducers:"
for i in "${!REPROS[@]}"; do
  dir=$(dirname "${REPROS[$i]}")
  tag=$(basename "$dir")
  report="$dir/repro.report"
  desc_file="$dir/description"
  if [ -f "$desc_file" ]; then
    desc=$(head -1 "$desc_file")
  elif [ -f "$report" ]; then
    desc=$(grep -m1 'BUG: KASAN\|BUG: ' "$report" 2>/dev/null || head -2 "$report")
  else
    desc="(no report)"
  fi
  echo "  [$((i + 1))] $tag"
  echo "      $desc"
done
echo ""
echo -n "Select reproducer to run (1-${#REPROS[@]}): "
read -r SELECTION

if ! [[ "$SELECTION" =~ ^[0-9]+$ ]] || [ "$SELECTION" -lt 1 ] || [ "$SELECTION" -gt "${#REPROS[@]}" ]; then
  echo "Invalid selection"
  exit 1
fi

REPRO_CPROG="${REPROS[$((SELECTION - 1))]}"
OUT_BIN="/tmp/repro_${SELECTION}_bin"
TMP_C="/tmp/repro_${SELECTION}.c"

cp "$REPRO_CPROG" "$TMP_C"

echo "Compiling: $REPRO_CPROG -> $TMP_C"
gcc -static -O0 -g -o "$OUT_BIN" "$TMP_C" -lpthread -ldl

echo "Compiled: $OUT_BIN"

echo "Copying reproducer into VM image..."
IMAGE=${PROJECT_DIR}/image/buildroot/output/images/rootfs_repro.ext4
if [[ -n "${USE_DEBIAN}" ]]; then
  IMAGE=${PROJECT_DIR}/image/trixie.img
fi
sudo mkdir -p /mnt/img_root
sudo mount -o loop ${IMAGE} /mnt/img_root
sudo cp "$OUT_BIN" /mnt/img_root/root/repro
sudo umount /mnt/img_root

echo "Booting VM and running reproducer..."
qemu-system-x86_64 \
  -M pc \
  -kernel "${PROJECT_DIR}/linux/arch/x86/boot/bzImage" \
  -drive file=${IMAGE},if=virtio,format=raw \
  -append "net.ifnames=0 root=/dev/vda console=ttyS0 selinux=0 mitigations=off panic=1" \
  -net nic,model=virtio \
  -net user,hostfwd=tcp::11022-:22 \
  -nographic \
  -cpu host \
  -smp 2 \
  -m 2048 \
  -enable-kvm 2>&1 | tee /tmp/repro_output.log
