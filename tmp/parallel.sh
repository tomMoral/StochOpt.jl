#!/bin/sh

START_TIME=$SECONDS

task () {
    local var=$1
    printf "Dataset: $var\n"
    julia ./tmp/parallel_exp_1_2_compute_bounds_SAGA_nice.jl $var
}

for var in "$@"
do
    task "$var" &
done

wait

ELAPSED_TIME=$(($SECONDS - $START_TIME))
printf "\n\nTotal elapsed time: $(($ELAPSED_TIME/3600)) h $(($ELAPSED_TIME/60)) min $(($ELAPSED_TIME%60)) sec\n"    

