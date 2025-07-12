#!/usr/bin/env bash

set -e

# Wrapper for the setup command
function setup_flashx () {
    objdir="${1}"

    echo -n "Setup ${objdir}: "

    setup_cmd="Sedov -portable -auto -2d +sparkbase2d"
    parfile="tests/test_amr_spark_2d.par"

    ${BASE_PATH}/Flash-X/setup ${setup_cmd} \
        -objdir=${PWD}/${objdir} -parfile=${parfile} -site=raptor-debug > setup.log 2>&1
    mv setup.log ${objdir}/setup.log

    if ! grep "SUCCESS" "${objdir}/setup.log"
    then
        echo "ERROR: Flash-X setup failed for ${objdir}."
        exit
    fi
}

# Build Flash-X in the given objdir
# Takes care of completely excluding EOS from the build
function build_flashx () {
    objdir="${1}"

    echo -n "Build ${objdir}: "

    make -C "${objdir}" -j >& /dev/null
    # Rebuild EOS without LTO
    cd ${objdir}
    ${BASE_PATH}/openmpi-5.0.6-install/bin/mpif90 -c -g -O2 -fdefault-real-8 -fdefault-double-8 \
        -DMAXBLOCKS=1000 -DNXB=16 -DNYB=16 -DNZB=1 -DN_DIM=2 Eos_multiDim.F90 -o Eos_multiDim.o
    cd - >& /dev/null

    # Rebuild Flash-X
    make -C "${objdir}" -j >& "${objdir}/make.log"

    if ! grep "SUCCESS" "${objdir}/make.log"
    then
        echo "ERROR: Flash-X build failed for ${objdir}."
        exit
    fi
}

# Reference run
objdir=sedov_spark_reference
setup_flashx "${objdir}"
sed -i 's/\!#define ENABLE_CONSTANT_DT/#define ENABLE_CONSTANT_DT/' "${objdir}/Driver_evolveAll.F90"
build_flashx "${objdir}"

# Baseline (truncate all of Hydro)
objdir=sedov_spark_baseline
setup_flashx "${objdir}"
sed -i 's/\!#define ENABLE_CONSTANT_DT/#define ENABLE_CONSTANT_DT/' "${objdir}/Driver_evolveAll.F90"
sed -i 's/\!#define ENABLE_TRUNC_HYDRO/#define ENABLE_TRUNC_HYDRO/' "${objdir}/Hydro.F90"
build_flashx "${objdir}"

# Exclude Recon
objdir=sedov_spark_excl_recon
setup_flashx "${objdir}"
sed -i 's/\!#define ENABLE_CONSTANT_DT/#define ENABLE_CONSTANT_DT/' "${objdir}/Driver_evolveAll.F90"
sed -i 's/\!#define ENABLE_TRUNC_HYDRO/#define ENABLE_TRUNC_HYDRO/' "${objdir}/Hydro.F90"
sed -i 's/\!#define EXCLUDE_RECON/#define EXCLUDE_RECON/' "${objdir}/hy_rk_getFaceFlux.F90"
build_flashx "${objdir}"

# Exclude Recon and Riemann
objdir=sedov_spark_excl_recon_riemann
setup_flashx "${objdir}"
sed -i 's/\!#define ENABLE_CONSTANT_DT/#define ENABLE_CONSTANT_DT/' "${objdir}/Driver_evolveAll.F90"
sed -i 's/\!#define ENABLE_TRUNC_HYDRO/#define ENABLE_TRUNC_HYDRO/' "${objdir}/Hydro.F90"
sed -i 's/\!#define EXCLUDE_RECON/#define EXCLUDE_RECON/' "${objdir}/hy_rk_getFaceFlux.F90"
sed -i 's/\!#define EXCLUDE_RIEMANN/#define EXCLUDE_RIEMANN/' "${objdir}/hy_rk_getFaceFlux.F90"
build_flashx "${objdir}"

# Exclude Recon and Update
objdir=sedov_spark_excl_recon_update
setup_flashx "${objdir}"
sed -i 's/\!#define ENABLE_CONSTANT_DT/#define ENABLE_CONSTANT_DT/' "${objdir}/Driver_evolveAll.F90"
sed -i 's/\!#define ENABLE_TRUNC_HYDRO/#define ENABLE_TRUNC_HYDRO/' "${objdir}/Hydro.F90"
sed -i 's/\!#define EXCLUDE_RECON/#define EXCLUDE_RECON/' "${objdir}/hy_rk_getFaceFlux.F90"
sed -i 's/\!#define EXCLUDE_UPDATESOLN/#define EXCLUDE_UPDATESOLN/' "${objdir}/Hydro_advance.F90"
build_flashx "${objdir}"
