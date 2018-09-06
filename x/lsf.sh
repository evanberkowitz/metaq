#!/bin/bash

METAQ_BATCH_SCHEDULER="LSF"

function METAQ_JOB_RUNNING {
    lsfjobs -r -j $1 2>/dev/null | grep $1 2>/dev/null | grep -v lsfjobs 2>/dev/null 
}
