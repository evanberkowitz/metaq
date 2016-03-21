#!/bin/bash

METAQ_BATCH_SCHEDULER="PBS"

function METAQ_JOB_RUNNING {
    qstat $1 2>/dev/null | grep $1
}
