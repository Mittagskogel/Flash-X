#!/usr/bin/env bash

# Number of processes to use per experiment
EXP_PROCS=32

# Launch command for Flash-X
# launch_cmd="srun -n ${EXP_PROCS} --exclusive"
launch_cmd="mpirun -n ${EXP_PROCS} --bind-to none"

jobs=(sedov_spark_reference \
      sedov_spark_baseline \
      sedov_spark_excl_recon \
      sedov_spark_excl_recon_riemann \
      sedov_spark_excl_recon_update)

# Run jobs in parallel
parallel -j $(( nproc / ${EXP_PROCS} )) --progress cd {} "&&" \
    ${launch_cmd} flashx ">" run_raw.log "2>&1" \
    ::: ${jobs[@]}
