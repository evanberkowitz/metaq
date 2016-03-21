#!/bin/bash

METAQ_BATCH_SCHEDULER="SLURM"

function METAQ_JOB_RUNNING {
    squeue -j $1 2>/dev/null | grep $1
}
