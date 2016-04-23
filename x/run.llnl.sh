#!/bin/bash
#MSUB -A [your account]
#MSUB -l nodes=[nodes]
#MSUB -l walltime=12:00:00
#MSUB -l qos=standby
#MSUB -l gres=lscratchd
#MSUB -W umask=0007
#MSUB -o /full/path/to/metaq/jobs/%j.log
#MSUB -j oe
#MSUB -N metaq.llnl

# LLNL clusters use a combination of MOAB and SLURM.  This run script is for that kind of environment.

# REQUIRED USER-SPECIFIED OPTIONS

METAQ=/full/path/to/metaq       # Specifies the full path to the metaq folder itself.
METAQ_JOB_ID=${SLURM_JOB_ID}    # Any string.  You don't have to use the batch scheduler ID,
                                # but you should ensure that the METAQ_JOB_ID is unique.
METAQ_NODES=${SLURM_NNODES}     # Integer, which should be less than or equal to the nodes specified to the batch scheduler.
                                # But if it's less than, you're guaranteeing you're wasting resources.
METAQ_RUN_TIME=43200              # Seconds, should match the above walltime=15:00.
                                # You may also specify times in the format for the #METAQ MIN_WC_TIME flag, [[HH:]MM:]SS.
METAQ_MACHINE=machine           # Any string. Right now doesn't do anything, but it could in the future!
                                # Would interact with METAQ MACHINE flag.


# OPTIONAL USER-SPECIFIED OPTIONS, with their defaults
# These may be omitted if you want.

METAQ_TASK_FOLDERS=(            # A bash array of priority-ordered absolute paths in which to look for tasks.
    $METAQ/priority             # This allows a user to segregate tasks and order their importance based on any number of 
    $METAQ/todo                 # metrics.  Our original use was to separate tasks by nodes, so that we could waste as little
    )                           # time as possible looking for a "big" task.
METAQ_GPUS=$[ METAQ_NODES * 1 ] # An integer describing how many GPUs are allocated to this job.
                                # How many GPUs to specify is a bit of a subtle business.  See METAQ/README.txt for more discussion.
METAQ_MAX_LAUNCHES=1048576      # An integer that limits the number of tasks that can be successfully launched.  Default is 2^20, essentially infinite.
METAQ_LOOP_FOREVER=false        # Bash booleans {true,false}.  Should you run out the wall clock?
                                # If METAQ_LOOP_FOREVER is true then METAQ will continue to look for remaining tasks,
                                # even if it finds none and it is not waiting for any tasks to finish.
METAQ_SLEEPY_TIME=3             # Number of seconds to sleep before repeating the main task-attempting loop.
METAQ_VERBOSITY=2               # How much detail do you want to see?
                                # Levels of detail are offset by tabbing 4 spaces.

# ANYTHING ELSE YOU WANT TO DO BEFORE LAUNCHING.
# For example, you can have this script resubmit itself.
# Or, if you have a script for populating the todo/priority folders, you can run it now.

# ATTACK THE QUEUE
source ${METAQ}/x/launch.sh     # ANYTHING BELOW HERE IS NOT GUARANTEED TO RUN!
                                # For example, if the tasks run out the wall clock time, x/launch.sh never finishes.

# AND THAT IS ALL!
