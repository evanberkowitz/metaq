#!/bin/bash

############################
############################ CHECK REQUIRED OPTIONS
############################


if [[ -z "$METAQ" ]]; then
    echo "You must specify the (preferably absolute) path to the METAQ in the METAQ variable."
    exit
fi
if [[ ! -d ${METAQ} ]]; then
    echo "Queue does not exist: ${METAQ}"
    exit
fi
METAQ_X=${METAQ}/x

if [[ -z "$METAQ_JOB_ID" ]]; then
    echo "You must tell METAQ a job id in the METAQ_JOB_ID variable."
    exit
fi


if [[ -z "$METAQ_NODES" ]]; then
    echo "You must tell METAQ how many nodes are allocated to it in the METAQ_NODES variable."
    exit
fi

if [[ -z "$METAQ_RUN_TIME" ]]; then
    echo "You must tell METAQ how long this job will take via the METAQ_RUN_TIME variable."
    exit
fi

############################
############################ CHECK OPTIONAL OPTIONS
############################

if [[ -z "$METAQ_GPUS" ]]; then
    METAQ_GPUS=0
fi
if [[ -z "$METAQ_SLEEPY_TIME" ]]; then
    METAQ_SLEEPY_TIME=3 #seconds
fi
if [[ -z "$METAQ_VERBOSITY" ]]; then
    METAQ_VERBOSITY=2
fi
if [[ -z "$METAQ_LOOP_FOREVER" ]]; then
    METAQ_LOOP_FOREVER=false
fi
if [[ -z "$METAQ_MACHINE" ]]; then
    METAQ_MACHINE=machine
fi
if [[ -z "$METAQ_SIMULTANEOUS_TASKS" ]]; then
    METAQ_SIMULTANEOUS_TASKS=1048576
fi

if [[ -z "$METAQ_MIN_NODES" ]]; then
    METAQ_MIN_NODES=0
fi
if [[ -z "$METAQ_MIN_GPUS" ]]; then
    METAQ_MIN_GPUS=0
fi


############################
############################ GET METAQ LIBRARY
############################

if [[ ! -f "${METAQ_X}/metaq_lib.sh" ]]; then
    echo "METAQ library is missing from ${METAQ_X}/metaq_lib.sh" 
    exit
fi

source ${METAQ_X}/metaq_lib.sh

############################
############################ JOB SETUP
############################

METAQ_WORKING=${METAQ_WORKING_BASE}/${METAQ_JOB_ID}
METAQ_THIS_JOB=${METAQ_JOBS}/${METAQ_JOB_ID}
METAQ_LOG=${METAQ_THIS_JOB}/log

mkdir -p ${METAQ_WORKING} ${METAQ_THIS_JOB} ${METAQ_LOG} 2>/dev/null

METAQ_RESOURCES=${METAQ_THIS_JOB}/resources
rm $METAQ_RESOURCES 2>/dev/null

METAQ_PRINT 0 "This is job ${METAQ_JOB_ID}."
METAQ_START=$(date "+%Y-%m-%dT%H:%M:%S")
METAQ_START_SEC=$(date "+%s")
METAQ_CLOCK_LIMIT=$(echo "$METAQ_START_SEC $METAQ_RUN_TIME" | awk '{print $1+$2}')
METAQ_PRINT 0 "START ${METAQ_START}"
METAQ_PRINT 5 "start sec $METAQ_START_SEC"
METAQ_PRINT 5 "clock max $clock_max"

METAQ_PRINT 0 "Resources will be tallied in ${METAQ_RESOURCES}"
# Seed the $METAQ_RESOURCES file with the allocated number of nodes:
METAQ_PRINT 1 "${METAQ_NODES} nodes allocated to job ${METAQ_JOB_ID}" | tee $METAQ_RESOURCES
METAQ_PRINT 1 "${METAQ_GPUS}  gpus allocated to job ${METAQ_JOB_ID}"  | tee -a $METAQ_RESOURCES

if [[ -z "${METAQ_MAX_LAUNCHES}" ]]; then
    METAQ_PRINT 2 "METAQ_MAX_LAUNCHES not defined."
    METAQ_MAX_LAUNCHES=1048576 # 2^20
fi
METAQ_PRINT 0 "We will launch at most ${METAQ_MAX_LAUNCHES} queued items."
METAQ_LAUNCHES=0

############################
############################ CAREFULLY TRY TO DO A GIVEN TASK
############################

METAQ_ATTEMPT_RESULT=""
function METAQ_ATTEMPT_TASK {
    METAQ_TASK_FULL=$1
    METAQ_TASK=${METAQ_TASK_FULL##*/}
    METAQ_ATTEMPT_RESULT=""

    # If there isn't enough time remaining, skip.
    METAQ_TASK_TIME_REQUIRED=$(METAQ_TASK_CLOCK_REQUIREMENT $METAQ_TASK_FULL)
    METAQ_PRINT 3 "Time estimate:  $METAQ_TASK_TIME_REQUIRED"
    METAQ_PRINT 3 "Time remaining: $($METAQ_X/timespan $(METAQ_TIME_REMAINING) 2>/dev/null)"
    if [[ "$(METAQ_TIME_REMAINING)" -lt "$($METAQ_X/seconds $METAQ_TASK_TIME_REQUIRED 2>/dev/null)" ]]; then
        METAQ_PRINT 3 "Probably not enough time remaining."
        METAQ_ATTEMPT_RESULT="CLOCK"
        return
    fi

    # If there currently aren't enough available nodes or gpus for the task, skip.
    # If there cannot possibly be enough nodes, skip but say the task is IMPOSSIBLE.
    METAQ_TASK_NODES_REQUIRED=$(METAQ_TASK_NODE_REQUIREMENT $METAQ_TASK_FULL)
    METAQ_TASK_GPUS_REQUIRED=$(METAQ_TASK_GPU_REQUIREMENT $METAQ_TASK_FULL)
    METAQ_PRINT 3 "nodes required:  $METAQ_TASK_NODES_REQUIRED"
    METAQ_PRINT 3 "gpus  required:  $METAQ_TASK_GPUS_REQUIRED"
    METAQ_NODES_AVAILABLE=$(METAQ_AVAILABLE_NODES)
    METAQ_GPUS_AVAILABLE=$(METAQ_AVAILABLE_GPUS)
    METAQ_PRINT 3 "nodes available: $METAQ_NODES_AVAILABLE"
    METAQ_PRINT 3 "gpus  available: $METAQ_GPUS_AVAILABLE"
    if [[ ${METAQ_TASK_NODES_REQUIRED} -gt ${METAQ_NODES} ]]; then
        METAQ_PRINT 4 "Not enough nodes allocated to this job."
        METAQ_ATTEMPT_RESULT="IMPOSSIBLE"
        return
    fi
    if [[ ${METAQ_TASK_GPUS_REQUIRED} -gt ${METAQ_GPUS} ]]; then
        METAQ_PRINT 4 "Not enough gpus allocated to this job."
        METAQ_ATTEMPT_RESULT="IMPOSSIBLE"
        return
    fi
    if [[ ${METAQ_TASK_NODES_REQUIRED} -gt ${METAQ_NODES_AVAILABLE} ]]; then
        METAQ_PRINT 4 "Not enough nodes available."
        METAQ_ATTEMPT_RESULT="NODES"
        return
    fi
    if [[ ${METAQ_TASK_GPUS_REQUIRED} -gt ${METAQ_GPUS_AVAILABLE} ]]; then
        METAQ_PRINT 4 "Not enough gpus available."
        METAQ_ATTEMPT_RESULT="GPUS"
        return
    fi
    if [[ ${METAQ_MIN_NODES} -gt ${METAQ_TASK_NODES_REQUIRED} ]]; then
        METAQ_PRINT 4 "Job uses too few nodes (${METAQ_TASK_NODES_REQUIRED}) for current consideration (${METAQ_MIN_NODES})."
        METAQ_ATTEMPT_RESULT="MIN_NODES"
        return
    fi
    if [[ ${METAQ_MIN_GPUS} -gt ${METAQ_TASK_GPUS_REQUIRED} ]]; then
        METAQ_PRINT 4 "Job uses too few GPUs (${METAQ_TASK_GPUS_REQUIRED}) for current consideration (${METAQ_MIN_GPUS})."
        METAQ_ATTEMPT_RESULT="MIN_GPUS"
        return
    fi
    
    # Make sure you log the task to the requested location.
    METAQ_TASK_LOG=$(METAQ_TASK_LOG_FILE $METAQ_TASK_FULL)
    METAQ_TASK_PROJ=$(METAQ_TASK_PROJECT $METAQ_TASK_FULL)
    
    # If the task specified a project for accounting purposes, make sure you log that.
    if [[ ! -z "$METAQ_TASK_PROJ" ]]; then
        METAQ_TASK_PROJ=" for project $METAQ_TASK_PROJ"
    fi

    if mv $METAQ_TASK_FULL $METAQ_WORKING 2>/dev/null; then
        # If you successfully move the task script to the working directory, you know nobody else did the same.
        # Therefore, start it!
        (
            # Keep track of the run time:
            METAQ_TASK_START=$(date "+%s")
            
            # Allocate the resources required in the resources ledger.
            echo "-$METAQ_TASK_NODES_REQUIRED nodes dedicated to ${METAQ_WORKING}/${METAQ_TASK}${METAQ_TASK_PROJ} at $(date "+%Y-%m-%dT%H:%M")" >> $METAQ_RESOURCES
            echo "-$METAQ_TASK_GPUS_REQUIRED gpus dedicated to ${METAQ_WORKING}/${METAQ_TASK}${METAQ_TASK_PROJ} at $(date "+%Y-%m-%dT%H:%M")" >> $METAQ_RESOURCES

            # Make sure the METAQ log exists.
            touch ${METAQ_LOG}/${METAQ_TASK}.log

            # Make sure the task is executable:
            # chmod ug+x $METAQ_WORKING/$METAQ_TASK

            # DO THE HARD WORK
            if [[ -z "$METAQ_TASK_LOG" ]]; then
                # If the task did not specify a log, just to the METAQ log location.
                $METAQ_WORKING/$METAQ_TASK 2>&1 > ${METAQ_LOG}/${METAQ_TASK}.log
            else
                # If the task DID specify a log, log it to both the METAQ location and the requested location.
                $METAQ_WORKING/$METAQ_TASK 2>&1 | tee ${METAQ_LOG}/${METAQ_TASK}.log > $METAQ_TASK_LOG
            fi
            
            # The hard work is finished.  Time to clean up.
            
            # First, move the task to the finished folder
            mv $METAQ_WORKING/$METAQ_TASK $METAQ_FINISHED 2>/dev/null
            
            # Figure out how much time you spent:
            METAQ_TASK_END=$(date "+%s")
            METAQ_TASK_RUNTIME=$(echo "$METAQ_TASK_END $METAQ_TASK_START" | awk '{print $1-$2}')
            
            # Release the dedicated resources back into the ledger, and log the run time statistics.
            echo "+$METAQ_TASK_NODES_REQUIRED nodes released by ${METAQ_WORKING}/${METAQ_TASK}${METAQ_TASK_PROJ} at $(date "+%Y-%m-%dT%H:%M"). RUNTIME: ${METAQ_TASK_RUNTIME} seconds" >> $METAQ_RESOURCES
            echo "+$METAQ_TASK_GPUS_REQUIRED gpus released by ${METAQ_WORKING}/${METAQ_TASK}${METAQ_TASK_PROJ} at $(date "+%Y-%m-%dT%H:%M"). RUNTIME: ${METAQ_TASK_RUNTIME} seconds" >> $METAQ_RESOURCES
        ) &

        # Increment the launch counter by 1
        METAQ_LAUNCHES=$[ $METAQ_LAUNCHES + 1 ]
        
        # Report success
        METAQ_PRINT 3 "Launched."
        METAQ_ATTEMPT_RESULT="LAUNCHED"
    else 
        #If your move failed, some other job snagged the task before you could get to it.
        METAQ_PRINT 3 "$METAQ_TASK no longer available for execution."
        METAQ_ATTEMPT_RESULT="STOLEN"
    fi
    return 0
}

############################
############################ THUNDERCATS GO!!!!!!!!
############################

METAQ_PRINT 0 "===================================================================================="
METAQ_PRINT 0 "Launching tasks."
METAQ_LOOP_TASKS_REMAIN=true
while $METAQ_LOOP_TASKS_REMAIN || $METAQ_LOOP_FOREVER; do
    METAQ_LOOP_TASKS_REMAIN=false
    METAQ_LAUNCH_SUCCESS=false

    METAQ_PRINT 0 "+----------------------------------------------------------------------------------+"
    
    for METAQ_REMAINING in {$METAQ_PRIORITY,$METAQ_UNFINISHED}; do
        METAQ_PRINT 0 "Looping over work in ${METAQ_REMAINING}"
        for i in $METAQ_REMAINING/*; do
            if [[ ! $METAQ_LAUNCHES -lt $METAQ_MAX_LAUNCHES ]]; then break; fi
            while [[ "$(METAQ_CURRENT_TASKS)" == "$METAQ_SIMULTANEOUS_TASKS" ]]; do
                METAQ_PRINT 1 "Simultaneous task limit ($METAQ_SIMULTANEOUS_TASKS) encountered."
                METAQ_PRINT 2 "$($METAQ_X/timespan $(METAQ_TIME_REMAINING)) remains on the wall clock."
                METAQ_PRINT 2 "$(METAQ_AVAILABLE_NODES) nodes will sit idle until task completion."
                METAQ_PRINT 2 "$(METAQ_AVAILABLE_GPUS) gpus will sit idle until task completion."
                sleep 10
            done
            if [[ ! $i == "$METAQ_REMAINING/*" ]]; then
                METAQ_PRINT 1 $i;
                METAQ_ATTEMPT_TASK $i
                METAQ_PRINT 2 "${METAQ_ATTEMPT_RESULT}"
                if [[ (! "${METAQ_ATTEMPT_RESULT}" == "LAUNCHED") ]]; then
                    METAQ_LAUNCH_SUCCESS=true
                fi
                if [[ (! "${METAQ_ATTEMPT_RESULT}" == "CLOCK") && (! "${METAQ_ATTEMPT_RESULT}" == "IMPOSSIBLE") && (! "${METAQ_ATTEMPT_RESULT}" =~ "MIN_"*) ]]; then
                    METAQ_LOOP_TASKS_REMAIN=true
                fi
                sleep 1 #so that launched subprocesses have time to start.
            else
                METAQ_LOOP_TASKS_REMAIN=false
            fi
        done
    done
    
    if [[ ! $METAQ_LAUNCHES -lt $METAQ_MAX_LAUNCHES ]]; then 
        echo "Launched maximum number of tasks: ${METAQ_LAUNCHES}."
        break; 
    fi
    METAQ_PRINT 0 ""
    METAQ_PRINT 0 ""
    METAQ_PRINT 0 "Tried to launch all available work."
    if $METAQ_LOOP_TASKS_REMAIN || $METAQ_LOOP_FOREVER; then
        METAQ_PRINT 0 "Sleeping $METAQ_SLEEPY_TIME seconds."
        sleep $METAQ_SLEEPY_TIME
    elif [[ (! ${METAQ_LAUNCH_SUCCESS} ) || ("${METAQ_MIN_NODES}" -gt 1) || ("${METAQ_MIN_NODES}" -gt 1) ]] ; then
        METAQ_LOOP_TASKS_REMAIN=true
        METAQ_MIN_NODES=$[ METAQ_MIN_NODES / 2 ]
        METAQ_MIN_GPUS=$[ METAQ_MIN_NODES / 2 ]
        METAQ_PRINT 0 "Minimum task size requirements may have been too big."
        METAQ_PRINT 1 "New minimum node requirement ${METAQ_MIN_NODES} NODES"
        METAQ_PRINT 1 "New minimum gpu  requirement ${METAQ_MIN_GPUS} GPUS"
    fi
done

METAQ_PRINT 0 "No more work remains.  Waiting for task completion."
METAQ_PRINT 1 "$($METAQ_X/timespan $(METAQ_TIME_REMAINING)) remains on the wall clock."
METAQ_PRINT 1 "$(METAQ_AVAILABLE_NODES) nodes will sit idle until task completion."
METAQ_PRINT 1 "$(METAQ_AVAILABLE_GPUS) gpus will sit idle until task completion."

wait

############################
############################ CLEAN UP
############################

rmdir $METAQ_WORKING 2>/dev/null

############################
############################ AND FINALLY,
############################

METAQ_PRINT 0 "===================================================================================="
METAQ_FINISH=$(date "+%Y-%m-%dT%H:%M:%S")
METAQ_FINISH_SEC=$(date "+%s")
METAQ_PRINT 0 "START:   ${METAQ_START}"
METAQ_PRINT 0 "FINISH:  ${METAQ_FINISH}"
METAQ_TOTAL_SEC=$(( METAQ_FINISH_SEC - METAQ_START_SEC ))
METAQ_PRINT 0 "RUNTIME: ${METAQ_TOTAL_SEC} seconds ($($METAQ_X/timespan ${METAQ_TOTAL_SEC}))"

echo "-${METAQ_NODES} nodes released by ${METAQ_JOB_ID} at ${METAQ_FINISH}.  RUNTIME: ${METAQ_TOTAL_SEC} seconds ($($METAQ_X/timespan ${METAQ_TOTAL_SEC}))" >> $METAQ_RESOURCES
echo "-${METAQ_GPUS}  gpus released by ${METAQ_JOB_ID} at ${METAQ_FINISH}.  RUNTIME: ${METAQ_TOTAL_SEC} seconds ($($METAQ_X/timespan ${METAQ_TOTAL_SEC}))"  >>  $METAQ_RESOURCES

