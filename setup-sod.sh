#!/usr/bin/env bash

set -e

# List of offsets for AMR levels
offsets=(0 1 2)
# List of mantissas
mantissas=($(seq 4 1 52))

# Setup command
setup_cmd="Sod -portable -auto -2d +uhd +pm4dev +nolwf"
# Paramter file
parfile="tests/test_amr_unsplit_2d.par"
# Directory for automatic experiment runner
rundir=autorun.sod



mkdir -p $rundir

jobs=()

# Reference and specifically fail fast in the linking stage (missing mpfr.o)
reference=${rundir}/reference
mkdir -p ${reference}
${BASE_PATH}/Flash-X/setup ${setup_cmd} \
    -objdir=${PWD}/${reference} -parfile=${parfile} -site=raptor > setup.log 2>&1
mv setup.log ${reference}/setup.log
make -j -C ${reference} > ${reference}/make.log 2>&1

for offset in ${offsets[@]}
do
    echo -n "offset ${offset}:"

    for mantissa in ${mantissas[@]}
    do
        echo -n " ${mantissa}"

        id=ref${offset}_${mantissa}bit
        objdir=${rundir}/object_${id}

        jobs+=(${objdir})

        # Setup the problem directory
        mkdir -p ${objdir}
        cp -ra ${reference}/* ${objdir}/

        # Update preprocessor variables in Hydro
        sed -i 's/\!#define ENABLE_TRUNC_HYDRO/#define ENABLE_TRUNC_HYDRO/' ${objdir}/Hydro.F90
        sed -i 's/#define TRUNC_TO_M.*/#define TRUNC_TO_M '${mantissa}'/' ${objdir}/Hydro.F90
        sed -i 's/#define LVL_OFFSET.*/#define LVL_OFFSET '${offset}'/' ${objdir}/Hydro.F90
    done

    echo
done

# Finish build for each object in parallel
parallel --progress make -C {} ">" {}/make.log "2>&1" ::: ${jobs[@]}

success=$(grep -R "SUCCESS" ${rundir} |& grep make.log | wc -l)
echo "${success}/$(( ${#offsets[@]} * ${#mantissas[@]} + 1 )) builds successful."
