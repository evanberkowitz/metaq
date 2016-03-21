#!/bin/bash

#METAQ_PRINT N string
#Print string indented by N*(4 spaces) if N < METAQ_VERBOSITY, otherwise don't print it.
function METAQ_PRINT {
    if [[ "$1" -gt "${METAQ_VERBOSITY}" ]]; then
        return
    elif [[ "$1" == "0" ]]; then
        echo "${@:2}"
    else
        echo "    $(METAQ_PRINT $(( $1 - 1 )) ${@:2})"
    fi
}

############################
############################ FOLDERS
############################

METAQ_UNFINISHED=${METAQ}/todo
METAQ_PRIORITY=${METAQ}/priority
METAQ_HOLD=${METAQ}/hold
METAQ_FINISHED=${METAQ}/finished
METAQ_JOBS=${METAQ}/jobs
METAQ_WORKING_BASE=${METAQ}/working

mkdir -p ${METAQ_UNFINISHED} ${METAQ_PRIORITY} ${METAQ_HOLD} ${METAQ_FINISHED} ${METAQ_JOBS} ${METAQ_WORKING_BASE} 2>/dev/null

############################
############################ FUNCTIONS THAT PARSE METAQ FLAGS
############################

function METAQ_PARSE {
    grep '#METAQ' $2 2>/dev/null | grep $1 | head -n 1 | awk '{print $3}' 2>/dev/null
}

function METAQ_TASK_NODE_REQUIREMENT {
    #METAQ NODES N
    METAQ_PARSE NODES $1
}

function METAQ_TASK_GPU_REQUIREMENT {
    #METAQ GPUS G
    METAQ_PARSE GPUS $1
}

function METAQ_TASK_CLOCK_REQUIREMENT {
    #METAQ MIN_WC_TIME hh:mm:ss or SECONDS
    METAQ_PARSE MIN_WC_TIME $1
}

function METAQ_TASK_LOG_FILE {
    #METAQ LOG /absolute/path/to/log/file
    METAQ_PARSE LOG $1
}

function METAQ_TASK_PROJECT {
    #METAQ PROJECT some.string.you.want.for.accounting.purposes
    METAQ_PARSE PROJECT $1
}

function METAQ_TASK_MACHINE {
    #METAQ MACHINE comma,separated,list,of,machines,where,task,could,run
    METAQ_PARSE MACHINE $1
}


############################
############################ FUNCTIONS THAT MONITOR AVAILABLE RESOURCES
############################


function METAQ_AVAILABLE_GPUS {
    grep -i gpu $METAQ_RESOURCES | awk 'BEGIN{total=0} {total+=$1} END {print total}' 2>/dev/null
}

function METAQ_AVAILABLE_NODES {
    grep -i nodes $METAQ_RESOURCES | awk 'BEGIN{total=0} {total+=$1} END {print total}' 2>/dev/null
}

function METAQ_CURRENT_TASKS {
    echo $[ ( $(grep -i dedicated $METAQ_RESOURCES | wc -l) - $(grep -i released $METAQ_RESOURCES | wc -l) ) / 2 ]
}

function METAQ_TIME_REMAINING {
    METAQ_NOW=$(date "+%s")
    echo "$METAQ_CLOCK_LIMIT $METAQ_NOW" | awk '{print $1-$2}'
}

############################
############################ READ BATCH SCHEDULER FILE
############################

if [[ ! -f $(readlink -f ${METAQ_X}/batch.sh) ]]; then
    echo "${METAQ_X}/batch.sh does not point to a batch scheduler file."
    METAQ_BATCH_SCHEDULER=NONE
else
    source $(readlink -f ${METAQ_X}/batch.sh)
fi
