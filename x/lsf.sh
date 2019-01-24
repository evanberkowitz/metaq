#!/bin/bash

METAQ_BATCH_SCHEDULER="LSF"

function METAQ_JOB_RUNNING {
    bjobs -u all 2>/dev/null | grep $1 2>/dev/null
}
