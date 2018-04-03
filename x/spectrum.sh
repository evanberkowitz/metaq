#!/bin/bash

METAQ_BATCH_SCHEDULER="SPECTRUM LSF"

function METAQ_JOB_RUNNING {
    bjobs -l $1 2>/dev/null | grep $1
}
