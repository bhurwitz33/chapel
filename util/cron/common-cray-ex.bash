#!/usr/bin/env bash

CWD=$(cd $(dirname ${BASH_SOURCE[0]}) ; pwd)

module unload $(module --terse list 2>&1 | grep PrgEnv-)
module load PrgEnv-gnu
module load cray-pmi

# Work around cxi provider bugs that limit memory registration
export CHPL_RT_MAX_HEAP_SIZE="50%"
export CHPL_LAUNCHER_MEM=unset
