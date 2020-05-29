#!/bin/bash
#SBATCH -A [your account]
#SBATCH -N 10
#SBATCH -t 15:00
#SBATCH [whatever other options]
#SBATCH -o /full/path/to/metaq/job/%J/log/%J.log
#SBATCH -N metaq_example_job

# REQUIRED USER-SPECIFIED OPTIONS

METAQ=/full/path/to/metaq       # Specifies the full path to the metaq folder itself.
METAQ_JOB_ID=${SLURM_JOB_ID}    # Any string.  You don't have to use the batch scheduler ID,
                                # but you should ensure that the METAQ_JOB_ID is unique.
METAQ_NODES=${SLURM_NNODES}     # Integer, which should be less than or equal to the nodes specified to the batch scheduler.
                                # But if it's less than, you're guaranteeing you're wasting resources.
METAQ_RUN_TIME=900              # Seconds, should match the above walltime=15:00.
                                # You may also specify times in the format for the #METAQ MIN_WC_TIME flag, [[HH:]MM:]SS.
METAQ_MACHINE=machine           # Any string. Right now doesn't do anything, but it could in the future!
                                # Would interact with METAQ MACHINE flag.


# OPTIONAL USER-SPECIFIED OPTIONS, with their defaults
# These may be omitted if you want.

METAQ_TASK_FOLDERS=(            # A bash array of priority-ordered absolute paths in which to look for tasks.
    $METAQ/priority             # This allows a user to segregate tasks and order their importance based on any number of
    $METAQ/todo                 # metrics.  Our original use was to separate tasks by nodes, so that we could waste as little
    )                           # time as possible looking for a "big" task.
METAQ_GPUS=0                    # An integer describing how many GPUs are allocated to this job.
                                # How many GPUs to specify is a bit of a subtle business.  See METAQ/README.txt for more discussion.
METAQ_MAX_LAUNCHES=1048576      # An integer that limits the number of tasks that can be successfully launched.  Default is 2^20, essentially infinite.
METAQ_LOOP_FOREVER=false        # Bash booleans {true,false}.  Should you run out the wall clock?
                                # If METAQ_LOOP_FOREVER is true then METAQ will continue to look for remaining tasks,
                                # even if it finds none and it is not waiting for any tasks to finish.
METAQ_SLEEP_AFTER_LAUNCH=0      # seconds to sleep after a task is successfully launched.
                                # We suspected that slowing down the submission might solve some unusual behavior we
                                # experienced when multiple METAQ jobs ran simultaneously.
METAQ_SLEEPY_TIME=3             # Number of seconds to sleep before repeating the main task-attempting loop.
METAQ_VERBOSITY=2               # How much detail do you want to see?
                                # Levels of detail are offset by tabbing 4 spaces.
METAQ_SIMULTANEOUS_TASKS=1048576 # An integer that limits how many tasks can run concurrently.
                                 # Some environments limit how many simultaneous tasks you can submit.  For example,
                                 # [on Titan, users are artificially limited to 100 simultaneous aprun processes](https://www.olcf.ornl.gov/kb_articles/using-the-aprun-command/).
METAQ_MIN_NODES=0               # Integers that puts a lower size limit on jobs.
METAQ_MIN_GPUS=0                # If the main loop decides that there were no possible jobs, it will halve these minimal
                                # values and loop again.  It will only concede that there are truly no possible jobs when
                                # these minimal values are <= 1.
METAQ_MAX_NODES=${METAQ_NODES}  # Integers that puts an upper size limit on jobs.
METAQ_MAX_GPUS=${METAQ_GPUS}    # If the main loop decides that there were no possible jobs, it will double these maximal
                                # values and loop again.  It will only concede that there are truly no possible jobs when
                                # these maximal values max out at METAQ_NODES and METAQ_GPUS respectively.
METAQ_SORT_TASKS=sort           # How to sort the result of finding tasks.
                                # A good choice can be shuf, the command-line utility that shuffles input lines.
METAQ_SKIP_ON_STOLEN=false      # {false,directory,reset}, what to do if a task is stolen.
                                #     On directory, break out of this directory and proceed to the next one.
                                #     On reset, begin the loop over METAQ_TASK_FOLDERS again.
                                #     On false, or anything else, just look at the next task.


# ANYTHING ELSE YOU WANT TO DO BEFORE LAUNCHING.
# For example, you can have this script resubmit itself.
# Or, if you have a script for populating the todo/priority folders, you can run it now.

# ATTACK THE QUEUE
source ${METAQ}/x/launch.sh     # ANYTHING BELOW HERE IS NOT GUARANTEED TO RUN!
                                # For example, if the tasks run out the wall clock time, x/launch.sh never finishes.

# AND THAT IS ALL!
