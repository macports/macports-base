#!/bin/sh

set -x

make CC=clang-mp-17 LD=clang-mp-17 CFLAGS="-g -O2 -std=c99 -Wextra -Wall -fPIC -arch arm64 -arch x86_64 -DHAVE_CONFIG_H -fprofile-instr-generate -fcoverage-mapping"

export LLVM_PROFILE_FILE="${PWD}/dtrace.%p.rawprof"
rm -f "${PWD}"/*.rawprof
make test CC=clang-mp-17 LD=clang-mp-17

llvm-profdata-mp-17 merge -sparse "${PWD}"/*.rawprof -o "${PWD}/dtrace.profdata"
llvm-cov-mp-17 show -arch x86_64 -format=html darwintrace.dylib -instr-profile="${PWD}/dtrace.profdata" > report.html
llvm-cov-mp-17 report -arch x86_64 darwintrace.dylib -instr-profile="${PWD}/dtrace.profdata"
