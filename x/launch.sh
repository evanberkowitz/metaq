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

if [[ -z "$METAQ_MACHINE" ]]; then
    echo "You must tell METAQ a machine name via the METAQ_MACHINE variable."
    exit
fi

############################
############################ CHECK OPTIONAL OPTIONS
############################

if [[ -z "$METAQ_GPUS" ]]; then
    METAQ_GPUS=0
fi

if [[ -z "$METAQ_SLEEP_AFTER_LAUNCH" ]]; then
    METAQ_SLEEP_AFTER_LAUNCH=0 #seconds
fi
if [[ -z "$METAQ_SLEEPY_TIME" ]]; then
    METAQ_SLEEPY_TIME=3 #seconds
fi
if [[ -z "$METAQ_SLEEPY_TIME_TASK_SATURATION" ]]; then
    METAQ_SLEEPY_TIME_TASK_SATURATION=10 #seconds
fi

if [[ -z "$METAQ_VERBOSITY" ]]; then
    METAQ_VERBOSITY=2
fi
if [[ -z "$METAQ_LOOP_FOREVER" ]]; then
    METAQ_LOOP_FOREVER=false
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

if [[ -z "$METAQ_MAX_NODES" ]]; then
    METAQ_MAX_NODES=$METAQ_NODES;
fi
if [[ -z "$METAQ_MAX_GPUS" ]]; then
    METAQ_MAX_GPUS=$METAQ_GPUS;
fi

if [[ "$METAQ_MAX_NODES" -gt "$METAQ_NODES" ]]; then
    echo "You set METAQ_MAX_NODES to $METAQ_MAX_NODES which is more than this job's allocated METAQ_NODE count $METAQ_NODES."
    echo "    For safety and sensibility this is automatically overridden, so that METAQ_MAX_NODES is $METAQ_NODES."
    METAQ_MAX_NODES=$METAQ_NODES
fi
if [[ "$METAQ_MAX_GPUS" -gt "$METAQ_GPUS" ]]; then
    echo "You set METAQ_MAX_GPUS to $METAQ_MAX_GPUS which is more than this job's allocated METAQ_GPU count $METAQ_GPUS."
    echo "    For safety and sensibility this is automatically overridden, so that METAQ_MAX_GPUS is $METAQ_GPUS."
    METAQ_MAX_GPUS=$METAQ_GPUS
fi
if [[ -z "$METAQ_SORT_TASKS" ]]; then
    METAQ_SORT_TASKS="sort"
fi
if [[ -z "$METAQ_SKIP_ON_STOLEN" ]]; then
    METAQ_SKIP_ON_STOLEN="false"
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
############################ CHECK OPTION CONSISTENCY
############################

if [[ "$METAQ_MAX_NODES" -lt "$METAQ_MIN_NODES" ]]; then
    METAQ_PRINT 0 "You specified inconsistent task requirements:"
    METAQ_PRINT 1 "You mandated the  largest task be ${METAQ_MAX_NODES} nodes"
    METAQ_PRINT 1 "         but the smallest task be ${METAQ_MIN_NODES} nodes"
    METAQ_PRINT 0 "Exiting."
    exit
fi
if [[ "$METAQ_MAX_GPUS" -lt "$METAQ_MIN_GPUS" ]]; then
    METAQ_PRINT 0 "You specified inconsistent task requirements:"
    METAQ_PRINT 1 "You mandated the  largest task be ${METAQ_MAX_GPUS} GPUs"
    METAQ_PRINT 1 "         but the smallest task be ${METAQ_MIN_GPUS} GPUs"
    METAQ_PRINT 0 "Exiting."
    exit
fi

############################
############################ JOB SETUP
############################

METAQ_PRINT 0 "#############################################################################"
METAQ_PRINT 0 "#                     __  __ ______ _______       ____                      #"
METAQ_PRINT 0 "#                    |  \/  |  ____|__   __|/\   / __ \                     #"
METAQ_PRINT 0 "#                    | \  / | |__     | |  /  \ | |  | |                    #"
METAQ_PRINT 0 "#                    | |\/| |  __|    | | / /\ \| |  | |                    #"
METAQ_PRINT 0 "#                    | |  | | |____   | |/ ____ \ |__| |                    #"
METAQ_PRINT 0 "#                    |_|  |_|______|  |_/_/    \_\___\_\                    #"
METAQ_PRINT 0 "#                                                                           #"
METAQ_PRINT 0 "#############################################################################"

METAQ_PRINT 0 "And so begins METAQ job ${METAQ_JOB_ID}."
METAQ_START=$(date "+%Y-%m-%dT%H:%M:%S")
METAQ_START_SEC=$(date "+%s")
METAQ_CLOCK_LIMIT=$(echo "$METAQ_START_SEC $METAQ_RUN_TIME" | awk '{print $1+$2}')
METAQ_PRINT 0 "START ${METAQ_START}"
METAQ_PRINT 5 "start sec $METAQ_START_SEC"
METAQ_PRINT 5 "clock max $clock_max"

METAQ_WORKING=${METAQ_WORKING_BASE}/${METAQ_MACHINE}/${METAQ_JOB_ID}
METAQ_THIS_JOB=${METAQ_JOBS}/${METAQ_JOB_ID}
METAQ_LOG=${METAQ_THIS_JOB}/log

mkdir -p ${METAQ_WORKING} ${METAQ_THIS_JOB} ${METAQ_LOG} 2>/dev/null

METAQ_RESOURCES="${METAQ_THIS_JOB}/resources.${METAQ_START//:/}"
rm $METAQ_RESOURCES 2>/dev/null


METAQ_PRINT 0 "Resources will be tallied in ${METAQ_RESOURCES}"
# Seed the $METAQ_RESOURCES file with the allocated number of nodes:
METAQ_PRINT 1 "${METAQ_NODES} nodes allocated to job ${METAQ_JOB_ID} at $METAQ_START" | tee $METAQ_RESOURCES
METAQ_PRINT 1 "${METAQ_GPUS}  gpus allocated to job ${METAQ_JOB_ID} at $METAQ_START"  | tee -a $METAQ_RESOURCES

METAQ_PRINT 1 "Symbolically linking $METAQ_RESOURCES"
METAQ_PRINT 1 "__________________to ${METAQ_THIS_JOB}/resources ..."
rm ${METAQ_THIS_JOB}/resources 2>/dev/null
if ln -s ${METAQ_RESOURCES} ${METAQ_THIS_JOB}/resources; then
    METAQ_PRINT 2 "Success!"
else
    METAQ_PRINT 2 "Failure!"
fi

if [[ -z "${METAQ_MAX_LAUNCHES}" ]]; then
    METAQ_PRINT 5 "METAQ_MAX_LAUNCHES not defined."
    METAQ_MAX_LAUNCHES=1048576 # 2^20
fi
METAQ_PRINT 0 "We will launch at most ${METAQ_MAX_LAUNCHES} queued items."
METAQ_LAUNCHES=0

# If the user hasn't specified the task folders, use the default folders
METAQ_PRINT 0 "We will look for tasks in ${#METAQ_TASK_FOLDERS[@]} folders."
if [[ "0" == "${#METAQ_TASK_FOLDERS[@]}" ]]; then
    METAQ_TASK_FOLDERS=($METAQ_PRIORITY $METAQ_UNFINISHED)
    METAQ_PRINT 2 "Looking in the default folders."
fi
for METAQ_TASK_FOLDER in ${METAQ_TASK_FOLDERS[@]}; do
    METAQ_PRINT 1 "$METAQ_TASK_FOLDER"
done

############################
############################ PREPARE FOR FAILURE
############################

_METAQ_INTERRUPT() {

    echo ""
    echo
    echo "METAQ IS INTERRUPTED"
    echo $(date "+%Y-%m-%dT%H:%M:%S")
    echo "KILLING DEPENDENT PROCESSES"
    kill $(jobs -p)
    echo "MOVING WORKING TASKS TO PRIORITY"
    mv $METAQ_WORKING/* ${METAQ_PRIORITY} 2>/dev/null
    echo "EXITING."
    exit

}

trap _METAQ_INTERRUPT SIGHUP SIGINT SIGQUIT SIGABRT SIGKILL SIGALRM SIGTERM

############################
############################ CAREFULLY TRY TO DO A GIVEN TASK
############################

METAQ_ATTEMPT_RESULT=""
function METAQ_ATTEMPT_TASK {

    METAQ_TASK_FULL=$1
    METAQ_TASK=${METAQ_TASK_FULL##*/}
    METAQ_ATTEMPT_RESULT=""

    if [[ ! -f ${METAQ_TASK_FULL} ]]; then
        #If the task file is gone, some other job snagged the task before you could get to it.
        METAQ_ATTEMPT_RESULT="STOLEN"
        return
    fi

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
    if [[ ${METAQ_MAX_NODES} -lt ${METAQ_TASK_NODES_REQUIRED} ]]; then
        METAQ_PRINT 4 "Job uses too many nodes (${METAQ_TASK_NODES_REQUIRED}) for current consideration (${METAQ_MAX_NODES})."
        METAQ_ATTEMPT_RESULT="MAX_NODES"
        return
    fi
    if [[ ${METAQ_MAX_GPUS} -lt ${METAQ_TASK_GPUS_REQUIRED} ]]; then
        METAQ_PRINT 4 "Job uses too many GPUs (${METAQ_TASK_GPUS_REQUIRED}) for current consideration (${METAQ_MAX_GPUS})."
        METAQ_ATTEMPT_RESULT="MAX_GPUS"
        return
    fi

    # Make sure you log the task to the requested location.
    METAQ_TASK_LOG=$(METAQ_TASK_LOG_FILE $METAQ_TASK_FULL)
    METAQ_TASK_PROJ=$(METAQ_TASK_PROJECT $METAQ_TASK_FULL)

    if [[ ! -z "$METAQ_TASK_LOG" ]]; then
        METAQ_TASK_LOG_FOLDER=$(dirname $METAQ_TASK_LOG);
        if [[ ! -d "$METAQ_TASK_LOG_FOLDER" ]]; then
            METAQ_PRINT 5 "Creating folder required by #METAQ LOG flag $METAQ_TASK_LOG_FOLDER"
            mkdir -p "$METAQ_TASK_LOG_FOLDER" 2>/dev/null
        fi
    fi

    # If the task specified a project for accounting purposes, make sure you log that.
    if [[ ! -z "$METAQ_TASK_PROJ" ]]; then
        METAQ_TASK_PROJ=" for project $METAQ_TASK_PROJ"
    fi

    if [[ ! -d "$METAQ_WORKING" ]]; then
        METAQ_PRINT 1 "$METAQ_WORKING surprisingly not found.  Recreating..."
        # Hopefully avoid a bad race condition
        mkdir -p $METAQ_WORKING
    fi

    if mv $METAQ_TASK_FULL $METAQ_WORKING/ 2>/dev/null; then
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
            # Touch the file to update the time stamp
            touch $METAQ_FINISHED/$METAQ_TASK

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

    for METAQ_REMAINING in ${METAQ_TASK_FOLDERS[@]}; do
        METAQ_PRINT 0 "Looping over tasks in ${METAQ_REMAINING}"

        METAQ_SMART_FOLDER=false
        METAQ_SMART_FOLDER_SETTINGS="$METAQ_REMAINING/.metaq"
        if [[ -f $METAQ_SMART_FOLDER_SETTINGS ]]; then
            METAQ_SMART_FOLDER=true
            METAQ_FOLDER_NODES=$(METAQ_FOLDER_NODE_REQUIREMENT $METAQ_SMART_FOLDER_SETTINGS)
            METAQ_FOLDER_TIME_REQUIRED=$(METAQ_FOLDER_CLOCK_REQUIREMENT $METAQ_SMART_FOLDER_SETTINGS)
            METAQ_FOLDER_TIME_REQUIRED=$($METAQ_X/seconds $METAQ_FOLDER_TIME_REQUIRED)
            METAQ_FOLDER_GPUS=$(METAQ_FOLDER_GPU_REQUIREMENT $METAQ_SMART_FOLDER_SETTINGS)
            if [[ -z "$METAQ_FOLDER_NODES" ]]; then
                METAQ_FOLDER_NODES=0
            fi
            if [[ -z "$METAQ_FOLDER_TIME_REQUIRED" ]]; then
                METAQ_FOLDER_TIME_REQUIRED=0
            fi
            if [[ -z "$METAQ_FOLDER_GPUS" ]]; then
                METAQ_FOLDER_GPUS=0
            fi
            METAQ_PRINT 1 "Folder settings suggest tasks require at least $METAQ_FOLDER_NODES nodes."
            METAQ_PRINT 1 "Folder settings suggest tasks require at least $METAQ_FOLDER_GPUS gpus."
            METAQ_PRINT 1 "Folder settings suggest tasks require at least $($METAQ_X/timespan $METAQ_FOLDER_TIME_REQUIRED) remaining wallclock time."
        else
            METAQ_PRINT 2 "Task folder contains no .metaq file."
        fi

        for i in $(find $METAQ_REMAINING -type f \( ! -path '*/.*' \)| $METAQ_SORT_TASKS ); do
            if [[ ! $METAQ_LAUNCHES -lt $METAQ_MAX_LAUNCHES ]]; then break; fi
            while [[ "$(METAQ_CURRENT_TASKS)" == "$METAQ_SIMULTANEOUS_TASKS" ]]; do
                METAQ_PRINT 1 "Simultaneous task limit ($METAQ_SIMULTANEOUS_TASKS) saturated."
                METAQ_PRINT 2 "It is currently $(date "+%Y-%m-%dT%H:%M:%S")."
                METAQ_PRINT 2 "$($METAQ_X/timespan $(METAQ_TIME_REMAINING)) remains on the wall clock."
                METAQ_PRINT 2 "$(METAQ_AVAILABLE_NODES) nodes will sit idle until task completion."
                METAQ_PRINT 2 "$(METAQ_AVAILABLE_GPUS) gpus will sit idle until task completion."
                sleep ${METAQ_SLEEPY_TIME_TASK_SATURATION}
            done

            if $METAQ_SMART_FOLDER && [[ $METAQ_FOLDER_NODES -gt $METAQ_NODES ]]; then
                METAQ_PRINT 1 "Skipping tasks because folder NODE requirement $METAQ_FOLDER_NODES exceeds the allocated $METAQ_NODES nodes."
                break
            fi
            if $METAQ_SMART_FOLDER && [[ $METAQ_FOLDER_GPUS -gt $METAQ_GPUS ]]; then
                METAQ_PRINT 1 "Skipping tasks because folder GPU requirement $METAQ_FOLDER_GPUS exceeds the allocated $METAQ_GPUS GPUs."
                break
            fi
            METAQ_CHECK_CLOCK=$(METAQ_TIME_REMAINING)
            if $METAQ_SMART_FOLDER && [[ $METAQ_FOLDER_TIME_REQUIRED -gt $METAQ_CHECK_CLOCK ]]; then
                METAQ_PRINT 1 "Skipping tasks because folder time requirement $($METAQ_X/timespan $METAQ_FOLDER_TIME_REQUIRED) exceeds the available clock time $($METAQ_X/timespan $METAQ_CHECK_CLOCK)."
                break
            fi
            METAQ_CHECK_NODES=$(METAQ_AVAILABLE_NODES)
            if $METAQ_SMART_FOLDER && [[ $METAQ_FOLDER_NODES -gt $METAQ_CHECK_NODES ]]; then
                METAQ_LOOP_TASKS_REMAIN=true
                METAQ_PRINT 1 "Skipping tasks because folder NODE requirement $METAQ_FOLDER_NODES exceeds the available nodes $METAQ_CHECK_NODES."
                break
            fi
            METAQ_CHECK_GPUS=$(METAQ_AVAILABLE_GPUS)
            if $METAQ_SMART_FOLDER && [[ $METAQ_FOLDER_GPUS -gt $METAQ_CHECK_GPUS ]]; then
                METAQ_LOOP_TASKS_REMAIN=true
                METAQ_PRINT 1 "Skipping tasks because folder GPU requirement $METAQ_FOLDER_GPUS exceeds the available gpus $METAQ_CHECK_GPUS."
                break
            fi

            METAQ_PRINT 1 $i;
            METAQ_ATTEMPT_TASK $i
            METAQ_PRINT 2 "${METAQ_ATTEMPT_RESULT} at $(date "+%Y-%m-%dT%H:%M:%S")"
            if [[ "${METAQ_ATTEMPT_RESULT}" == "LAUNCHED" ]]; then
                METAQ_LAUNCH_SUCCESS=true

                # Take a breath.
                if [[ "0" != "$METAQ_SLEEP_AFTER_LAUNCH" ]]; then
                    METAQ_PRINT 3 "After launch sleeping ${METAQ_SLEEP_AFTER_LAUNCH} seconds."
                    sleep $METAQ_SLEEP_AFTER_LAUNCH
                fi

            fi
            if [[ "${METAQ_ATTEMPT_RESULT}" == "STOLEN" ]]; then
                if [[ "${METAQ_SKIP_ON_STOLEN}" == "directory" || "${METAQ_SKIP_ON_STOLEN}" == "reset" ]]; then
                    METAQ_PRINT 2 "Since the task was stolen, skipping ${METAQ_SKIP_ON_STOLEN}"
                    break; # from the loop over tasks
                fi
            fi
            if [[ (! "${METAQ_ATTEMPT_RESULT}" == "CLOCK") && (! "${METAQ_ATTEMPT_RESULT}" == "IMPOSSIBLE") ]]; then
                METAQ_LOOP_TASKS_REMAIN=true
            fi
            sleep 1 #so that launched subprocesses have time to start.
        done

        # If we broke out of the directory, should we go back to priority tasks?
        if [[ "${METAQ_ATTEMPT_RESULT}" == "STOLEN" && "${METAQ_SKIP_ON_STOLEN}" == "reset" ]]; then
            METAQ_LOOP_TASKS_REMAIN=true    # We don't actually know---we have to loop again to decide if there are any tasks remaining.
            break; # from the loop over METAQ_TASK_FOLDERS
        fi
    done

    if [[ "${METAQ_ATTEMPT_RESULT}" == "STOLEN" && "${METAQ_SKIP_ON_STOLEN}" == "reset" ]]; then
        METAQ_ATTEMPT_RESULT="RESET"
        continue; # the main while loop.
    fi

    if [[ ! $METAQ_LAUNCHES -lt $METAQ_MAX_LAUNCHES ]]; then
        echo "Launched maximum number of tasks: ${METAQ_LAUNCHES}."
        break;
    fi

    METAQ_PRINT 0 ""
    METAQ_PRINT 0 ""
    METAQ_PRINT 0 "Tried to launch all available tasks."

    if (! ${METAQ_LAUNCH_SUCCESS} ) && $METAQ_LOOP_TASKS_REMAIN ; then
        METAQ_PRINT 0 "No tasks were launched on the last pass."
        if [[ ${METAQ_MIN_NODES} -gt 0 ]]; then
            METAQ_MIN_NODES=$[ METAQ_MIN_NODES / 2 ]
        fi
        if [[ ${METAQ_MIN_GPUS} -gt 0 ]]; then
            METAQ_MIN_GPUS=$[ METAQ_MIN_GPUS / 2 ]
        fi
        if [[ $METAQ_MAX_NODES -lt $METAQ_NODES ]]; then
            METAQ_MAX_NODES=$[ METAQ_MAX_NODES * 2 ]
            if [[ $METAQ_MAX_NODES -gt $METAQ_NODES ]]; then
                $METAQ_MAX_NODES=$METAQ_NODES
            fi
        fi
        if [[ $METAQ_MAX_GPUS -lt $METAQ_GPUS ]]; then
            METAQ_MAX_GPUS=$[ METAQ_MAX_GPUS * 2 ]
            if [[ $METAQ_MAX_GPUS -gt $METAQ_GPUS ]]; then
                $METAQ_MAX_GPUS=$METAQ_GPUS
            fi
        fi

        METAQ_PRINT 0 "Minimum task size requirements may have been too big."
        METAQ_PRINT 1 "New minimum node requirement: ${METAQ_MIN_NODES} NODES"
        METAQ_PRINT 1 "New minimum gpu  requirement: ${METAQ_MIN_GPUS} GPUS"
        METAQ_PRINT 0 "Maximum task size requirements may have been too small."
        METAQ_PRINT 1 "New maximum node requirement: ${METAQ_MAX_NODES} NODES"
        METAQ_PRINT 1 "New maximum gpu  requirement: ${METAQ_MAX_GPUS} GPUS"
    fi;

    if $METAQ_LOOP_TASKS_REMAIN || $METAQ_LOOP_FOREVER; then
        METAQ_PRINT 0 "Sleeping $METAQ_SLEEPY_TIME seconds."
        sleep $METAQ_SLEEPY_TIME
    fi
done

METAQ_PRINT 0 "No more tasks remains.  Waiting for task completion."
METAQ_PRINT 0 "It is currently $(date "+%Y-%m-%dT%H:%M:%S")."
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

METAQ_PRINT 1 "-${METAQ_NODES} nodes released by ${METAQ_JOB_ID} at ${METAQ_FINISH}.  RUNTIME: ${METAQ_TOTAL_SEC} seconds ($($METAQ_X/timespan ${METAQ_TOTAL_SEC}))" >> $METAQ_RESOURCES
METAQ_PRINT 1 "-${METAQ_GPUS}  gpus released by ${METAQ_JOB_ID} at ${METAQ_FINISH}.  RUNTIME: ${METAQ_TOTAL_SEC} seconds ($($METAQ_X/timespan ${METAQ_TOTAL_SEC}))"  >>  $METAQ_RESOURCES
