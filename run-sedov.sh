#!/usr/bin/env bash

set -e

# List of offsets for AMR levels
offsets=(0 1 2 3)
# List of mantissas
mantissas=($(seq 4 1 52))

# Directory for automatic experiment runner
rundir=autorun.sedov

# Launch command for Flash-X
# launch_cmd="srun -n 1 --exclusive"
launch_cmd="mpirun -n 1 --bind-to none"



jobs=(${rundir}/reference)

for offset in ${offsets[@]}
do
    for mantissa in ${mantissas[@]}
    do
        id=ref${offset}_${mantissa}bit
        objdir=${rundir}/object_${id}

        jobs+=(${objdir})
    done
done

# Run jobs in parallel
parallel --progress cd {} "&&" \
    ${launch_cmd} flashx ">" run_raw.log "2>&1" \
    ::: ${jobs[@]}

success=$(grep -R "FLASH run complete" ${rundir} |& grep sedov.log | wc -l)
echo "${success}/$(( ${#offsets[@]} * ${#mantissas[@]} + 1 )) runs successful."
