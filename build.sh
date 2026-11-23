#!/bin/sh
# Build Manic Miner '88 with mpm (devkit bin/mpm 2.2).
#   ./build.sh                 (mpm on the PATH; or MPM=/path/to/mpm ./build.sh)
# No def folder needed: the OZ names are in mmz88_oz.def beside the sources.
# Makes the RAM application  mmz88.app + mmz88.ap0 (top bank) + mmz88.ap1  (legacy .app
# format: OZ 4.6+ / OZ 5 Installer) and mmz88.epr (32K card: ap1 = bank $3E, then ap0 = $3F).
# Change TOP to mmz88_ap0_qa (shipped version) or mmz88_ap0 (unpatched) to build those.
set -e
cd "$(dirname "$0")"
MPM="${MPM:-mpm} -b"
TOP=mmz88_ap0_fast
$MPM $TOP.asm
$MPM mmz88_ap1.asm
for b in $TOP.bin mmz88_ap1.bin; do
  [ "$(wc -c < $b)" -eq 16384 ] || { echo "$b is not 16384 bytes"; exit 1; }
done
cp $TOP.bin mmz88.ap0
cp mmz88_ap1.bin mmz88.ap1
cat mmz88.ap1 mmz88.ap0 > mmz88.epr
# RAM application header, 40 bytes: $A5 $5A, 2 banks, flags 0, 4 reserved,
# then (offset, length) per bank: ap0 = 0,$4000  ap1 = 0,$4000  (6 unused entries)
printf '\245\132\002\000\000\000\000\000\000\000\000\100\000\000\000\100\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000' > mmz88.app
[ "$(wc -c < mmz88.app)" -eq 40 ] || { echo "mmz88.app is not 40 bytes"; exit 1; }
echo "built mmz88.app + mmz88.ap0 + mmz88.ap1 (RAM application) and mmz88.epr from $TOP"
