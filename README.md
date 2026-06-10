# ICTRA Project

The project consists in fuzzing a custom Linux kernel with intentionally vulnerable syscalls using Syzkaller, detecting Use-After-Free and Out-of-Bounds accesses via KASAN.

## Project Structure

| File                    | Notes                                                                                                                                               |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| `01_patch_kernel.sh`    | Adds 3 vulnerable syscalls (`ictra_uaf`, `ictra_heap_oob`, `ictra_static_oob`) to the kernel source                                                 |
| `02_build_kernel.sh`    | Configures and compiles the kernel with KASAN, KCOV, and debug symbols                                                                              |
| `03_build_syzkaller.sh` | Writes syzlang descriptions for the custom syscalls and builds Syzkaller                                                                            |
| `04_start_fuzzing.sh`   | Generates `syzkaller/manager.cfg` and launches `syz-manager` against a QEMU VM                                                                      |
| `patch_buildroot.sh`    | Injects SSH keys, host keys, and inittab into a buildroot image                                                                                     |
| `run_repro.sh`          | Lists and runs generated crash reproducers inside a VM                                                                                              |
| `patches/fs.patch`      | Adds a UAF in `vfs_write` triggered by `count == 4919`                                                                                              |
| `patches/net.patch`     | Adds an OOB write in `do_ip_setsockopt` via `IP_OPTIONS`                                                                                            |
| `patches/project.patch` | The complete patch ready to be applied to the Linux kernel containing all the changes included the update `lib/Makefile` to build the `dvkm` module |
| `linux`                 | The files changed from the original source                                                                                                          |
| `image/buildroot`       | The buildroot config                                                                                                                                |
| `syzkaller/workdir`     | All the crashes and reproduction files to execute the `run_repro.sh` script                                                                         |
| `dvkm.txt`              | Syzkaller description file to enable the fuzzing for the `dvkm` module                                                                              |

## Setup

> [!NOTE]
> You can clone the project, then move to a new directory and copy the overlay changes contained in `image`, `linux` and `syzkaller`, or you can simply apply the patches and execute the scripts.

Clone repositories

```bash
git clone --depth=1 https://github.com/torvalds/linux.git
git clone https://github.com/google/syzkaller.git
```

Copy project files

```bash
cp /path/to/ictra_project/*.sh .
cp -r /path/to/ictra_project/patches .
cp -r /path/to/ictra_project/syzkaller/sys/linux/ictra_*.txt syzkaller/sys/linux/
cp -r /path/to/ictra_project/syzkaller/sys/linux/ictra_*.const syzkaller/sys/linux/
```

Apply patches

```bash
cd linux
wget https://raw.githubusercontent.com/hardik05/Damn_Vulnerable_Kernel_Module/refs/heads/main/dvkm.c -O lib/dvkm.c
git apply ../patches/project.patch
cd ..
```

## Usage

Run the 3 steps in order:

```bash
./01_build_kernel.sh
./02_build_syzkaller.sh
./03_start_fuzzing.sh
```

To use a Debian image:

```bash
mkdir -p image && cd image
wget https://raw.githubusercontent.com/google/syzkaller/master/tools/create-image.sh
chmod +x create-image.sh && ./create-image.sh
cd ..
```

To use a buildroot image, build it and then patch it:

```bash
mkdir -p image && cd image
git clone https://github.com/buildroot/buildroot
cd buildroot
cp /path/to/ictra_project/image/buildroot/.config .
make -j $(nproc)
./patch_buildroot.sh
```

At this point you can start the fuzzer:

```bash
./03_start_fuzzing.sh
```

Set `USE_DEBIAN=1` in the script to use the Debian image instead of buildroot.

## Run a Reproducer

```bash
./run_repro.sh
```

Select a crash from the list; the script compiles and runs it inside a QEMU VM.
Set `USE_DEBIAN=1` in the script to use the Debian image instead of buildroot.
