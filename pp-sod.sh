#!/usr/bin/env bash

set -e

# List of offsets for AMR levels
offsets=(0 1 2)
# List of mantissas
mantissas=($(seq 5 1 53))
# List of checkpoint timesteps
steps=($(seq -w 0001 0001))

# Directory for automatic experiment runner
rundir=autorun.sod
# Directory for the reference solution
reference=${rundir}/reference



for step in ${steps[@]}
do
    echo "step ${step}:"
    for offset in ${offsets[@]}
    do
        echo -n "offset ${offset}:"

        outfile_sfocu="${rundir}/sfocu_ref${offset}_${step}.out"
        outfile_flops="${rundir}/perf_counts_ref${offset}_${step}.out"
        rm -f ${outfile_sfocu} ${outfile_flops}
        touch ${outfile_sfocu} ${outfile_flops}

        echo "mantissa" \
             " dens-${offset}-trunc"  \
             " dens-${offset}-double" \
             " dens-${offset}-float"  \
             " dens-${offset}-half"   \
             " dens-${offset}-trunc-store" \
             " dens-${offset}-trunc-load" \
             " dens-${offset}-original-store" \
             " dens-${offset}-original-load" \
             >> ${outfile_flops}

        for mantissa in ${mantissas[@]}
        do
            echo -n " ${mantissa}"

            id=ref${offset}_${mantissa}bit
            objdir=${rundir}/object_${id}

            # Get L1-Error >> sfocu_ref*.out
            sfocu ${objdir}/flashx_hdf5_chk_${step} \
                ${reference}/flashx_hdf5_chk_${step} | \
                grep -v "Couldn't read" >> \
                ${outfile_sfocu} || true

            # Read flop counters >> perf_counts_ref*.out
            echo -n "${mantissa}" >> ${outfile_flops}

            echo -n " "$(grep "Number of truncated flops:" ${objdir}/run_raw.log | \
                sed 's/Number of truncated flops://' | \
                paste -sd'+' | bc) >> ${outfile_flops}

            echo -n " "$(grep "Number of double flops:" ${objdir}/run_raw.log | \
                sed 's/Number of double flops://' | \
                paste -sd'+' | bc) >> ${outfile_flops}
            echo -n " "$(grep "Number of float flops:" ${objdir}/run_raw.log | \
                sed 's/Number of float flops://' | \
                paste -sd'+' | bc) >> ${outfile_flops}
            echo -n " "$(grep "Number of half flops:" ${objdir}/run_raw.log | \
                sed 's/Number of half flops://' | \
                paste -sd'+' | bc) >> ${outfile_flops}

            echo -n " "$(grep "Number of truncated stores:" ${objdir}/run_raw.log | \
                sed 's/Number of truncated stores://' | \
                paste -sd'+' | bc) >> ${outfile_flops}
            echo -n " "$(grep "Number of truncated loads:" ${objdir}/run_raw.log | \
                sed 's/Number of truncated loads://' | \
                paste -sd'+' | bc) >> ${outfile_flops}
            echo -n " "$(grep "Number of original stores:" ${objdir}/run_raw.log | \
                sed 's/Number of original stores://' | \
                paste -sd'+' | bc) >> ${outfile_flops}
            echo -n " "$(grep "Number of original loads:" ${objdir}/run_raw.log | \
                sed 's/Number of original loads://' | \
                paste -sd'+' | bc) >> ${outfile_flops}

            echo >> ${outfile_flops}
        done

        echo
    done
done
