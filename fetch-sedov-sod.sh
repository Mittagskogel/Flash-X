#!/usr/bin/env bash

set -e

function auto_extract () {
    matchfields="$1"

    # Autodetect offset and mantissa ranges:
    offsets=($(ls sfocu_ref*.out | sed 's/sfocu_ref\([0-9]\).*.out/\1/g'))
    mantissas=()

    for offset in ${offsets[@]}
    do
        mantissas+=($(grep object_ref[0-9] ./sfocu_ref${offset}*.out | \
            sed 's/.*object_ref[0-9]*_\([0-9]*\).*/\1/g'))
    done
    mantissas=($(printf "%s\n" "${mantissas[@]}" | sort -ug))

    echo -n 'mantissa '


    # Get offsets from sfocu output
    for offset in ${offsets[@]}
    do
        echo -n $(sed -n '/| L1-ErrNorm |/,/FAILURE\|SUCCESS/p; /FAILURE\|SUCCESS/q' ./sfocu_ref${offset}*.out | \
            grep ${matchfields} | sed 's/ .*//' | sed 's/ /-'${offset}' /g' | sed 's/$/-'${offset}'/g')" "
    done
    echo

    # Get error from selected field in sfocu output
    for m in ${mantissas[@]}
    do
        echo -n "$((m-1)) "
        for offset in ${offsets[@]}
        do
            echo -n $(sed -n '/object_ref'${offset}'_'${m}'bit/,/FAILURE\|SUCCESS/p' ./sfocu_ref${offset}*.out |\
                sed -n '/| L1-ErrNorm |/,/FAILURE\|SUCCESS/p' | grep ${matchfields} | \
                sed 's/[a-z 1-9]* | \([0-9.e\-]*\) .*/\1/')" "

            # Detect missing data
            grep 'object_ref'${offset}'_'${m}'bit' ./sfocu_ref${offset}*.out > /dev/null
            if [ $? -eq 1 ]
            then
               echo -n "NaN "
            fi
        done
        echo
    done

    echo
}

function fetch_batch () {
    o1=$1
    o2=$2
    s1=$3
    s2=$4
    key=$5
    rundir=$6
    archive=$7

    echo ${archive}

    offsets=($(seq -w $o1 $o2))
    steps=($(seq -w $s1 $s2))

    rsync ${rundir}/sfocu_ref*.out .
    rsync ${rundir}/perf_counts_ref*.out .

    for step in ${steps[@]}
    do
        echo $step

        outdir=${archive}_${step}

        mkdir -p ${outdir}

        mv sfocu_ref*_${step}.out ${outdir}/
        mv perf_counts_ref*_${step}.out ${outdir}/

        cd ${outdir}
        auto_extract ${key} > ./plot-data.out
        cd - >/dev/null
    done
}



mkdir -p plots

fetch_batch 0 2 0001 0001 dens \
    autorun.sod plots/sod

fetch_batch 0 3 0001 0001 dens \
    autorun.sedov plots/sedov
