#!/usr/bin/env bash
#
# Run GPU performance tests

CWD=$(cd $(dirname $0) ; pwd)
source $CWD/common-slurm-gasnet-cray-cs.bash
source $CWD/common-native-gpu.bash

module load cudatoolkit

export CHPL_GPU=nvidia
export CHPL_LAUNCHER_PARTITION=stormP100

export CHPL_COMM=none

export CHPL_NIGHTLY_TEST_CONFIG_NAME="perf.gpu-cuda"

export CHPL_TEST_PERF_CONFIG_NAME="1-node-p100"
source $CWD/common-native-gpu-perf.bash
# make sure this comes after setting SUBDIR (set by native-gpu-perf) and
# CONFIG_NAME
source $CWD/common-perf.bash


nightly_args="${nightly_args} -startdate 07/15/22"

$CWD/nightly -cron ${nightly_args}
