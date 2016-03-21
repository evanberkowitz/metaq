# METAQ

`METAQ` (pronounced "meta-queue") is a system for bundling tasks for supercomputing in an environment with a batch scheduler like [`SLURM`](https://en.wikipedia.org/wiki/Slurm_Workload_Manager) or [`PBS`](https://en.wikipedia.org/wiki/Portable_Batch_System).

In many cases, you might prefer to bundle many small tasks together to achieve better throughput or a charging discount.  `METAQ` is designed to allow you to submit big bundled jobs easily, by creating a queue for your own work (tasks), that will run in a near-optimal way, wasting very little of your allocation.

`METAQ` doesn't care about what the individual tasks are.  So, if you have multiple projects going at once, you can nevertheless use the same `METAQ` and the tasks will be queued and run side-by-side with no problem.

Essentially, this allows you to back-fill your tasks, and to submit jobs that build priority in the queue that you can add tasks to after submission.  Different users can put tasks in the same `METAQ` and (as long as the file permissions are liberal enough) can share the load.

# QUICK SUMMARY [quick-summary]

JOB SCRIPTS all do the same thing when launched by the BATCH SCHEDULER: look through your TASK SCRIPTS and start what's possible.

The BATCH SCHEDULER controls the computational resources.  This is chosen by the administrator of your computer.  Examples include SLURM and PBS.

JOB SCRIPTS     are bash scripts that get submitted to the scheduler, 
                contain some amount of user-specified `METAQ` options,
                convert BATCH SCHEDULER variables to `METAQ` variables, and 
                call `METAQ/x/launch.sh`

TASK SCRIPTS    get put in the `METAQ/todo` and `METAQ/priority` folders,
                describe their needed resources with #METAQ flags, and
                contain the hard work you want to do.

#Table of Contents

- METAQ
- [Quick Summary](#quick-summary)
- Table of Contents
- ...
- [Miscellaneous][]

# BASIC INTRODUCTION

Users create various task scripts to do some hard work (meaning supercomputing) as usual.  These task scripts can be essentially anything, as long as they contain some `METAQ` markup.  They can include setup steps and whatever else you want.  It is these task scripts that contain the command that tells the scheduler to put work onto the compute nodes (for example, in a SLURM environment these task scripts contain `srun` commands).

These task scripts exist in the `METAQ/todo` folder, or they can be symbolically linked in.  They will be moved to the `METAQ/working` folder and ultimately to the `METAQ/finished` folder upon completion.

Users also need to forumulate jobs script.  These scripts are what actually gets submitted to the scheduler.  So, it needs to have all the usual batch scheduler mark up.  It needs to convert the batch scheduler variables to `METAQ` variables.  Then, it executes `METAQ/x/launch.sh`, which is where all the magic happens.

`METAQ/x/launch.sh` essentially evaluates these steps:
```
loop over all possible remaining tasks until there are none:
    Check if you currently have enough resources (nodes, GPUs, clock time, etc.) to perform the task
    If so, move it to the working directory, deduct those resources from what's available, and launch it!
    Else, skip it!  
        But, if it is impossible, don't count this job as "remaining".
            Some examples of impossibility:
                The task needs more nodes than are allocated to this job.
                The remaining clock time isn't enough to complete the task.
```

`METAQ/x/launch.sh` logs the individual tasks separately in `METAQ/jobs/${METAQ_JOB_ID}/log/${task}.log` and tallies the available resources in `METAQ/jobs/${METAQ_JOB_ID}/resources`, where you can see which tasks got started when, and what resources they consumed.  My personal preference is to direct the output log of `METAQ/x/launch.sh` itself to `METAQ/jobs/${METAQ_JOB_ID}/log/` as well, but that is specified in the job script as an option to the batch scheduler.

# TASK SCRIPT STRUCTURE

Task scripts must be directly executable, so if you script in a language that isn't bash, you must include the correct shebang.  It need not be `bash`.  The structure of a task script is only very loosely constrained.  

You tell `METAQ` about the task by incorporating flags that `METAQ` understands into the task script.  A bare-bones script looks like this:
```bash
#!/bin/bash
#METAQ GPUS 2
#METAQ NODES 2
#METAQ MIN_WC_TIME 5:00
#METAQ PROJECT metaq.example.1

do setup
load modules
etc

echo "working hard"
aprun -n 2 [...]
echo "finished"
```

However, I often make the task scripts themselves legal submittable scripts, from the point of view of the batch scheduler.  This way, if something goes askew (for example, a job hits the wall clock time before a task is complete) you can manually clean up very easily (though `METAQ` provides some amount of automatic clean-up too).

So, a task script (in a PBS environment) might look like
```bash
#!/bin/bash
#PBS -A lgt100
#PBS -l nodes=2
#PBS -l walltime=5:00
#PBS -N NAME_OF_TASK

#METAQ GPUS 2
#METAQ NODES 2
#METAQ MIN_WC_TIME 5:00
#METAQ PROJECT metaq.example.1

do_setup
load_modules
etc

echo "working hard"
aprun -n 2 [...]
echo "finished"
```

This script can be qsubbed directly to PBS, thanks to the #PBS flags, but can also be understood by `METAQ` as a `METAQ` task.

However, as shown in the first example, all of the `#PBS` lines are not strictly necessary.  The essential features are that the script indicates to `METAQ` how many `NODES` and `GPUS` are required and the much time should remain on the job's wall clock before starting this task in `MIN_WC_TIME`.

Task scripts inherit the bash environment variables as the batch scheduler provides them, but do not have access to `METAQ` variables, and are not passed any parameters.  They should be relatively self-contained.

# METAQ FLAGS

`METAQ` flags are always passed each on their own line.  They always have the structure
`#METAQ FLAG VALUE`
Whitespace is not important, but there is never whitespace in a FLAG or in a VALUE.
`METAQ` only reads the first instance of a flag.  So if you put the same flag on two different lines, `METAQ` will pick the first one.
FLAGs are always CAPITALIZED.
So, in the above example, you see
```bash
#METAQ GPUS 2
#METAQ NODES 2
#METAQ MIN_WC_TIME 5:00
#METAQ PROJECT metaq.example.1
```

What FLAGs are understood by `METAQ` and what do they mean?

####`#METAQ NODES N`
This task requires N nodes.

####`#METAQ GPUS G`
This task requires G gpus.

####`#METAQ MIN_WC_TIME [[HH:]MM:]SS`
This task requires the job to still have HH:MM:SS available before starting.

This helps avoid having work that fails due to interruption.

You may specify times in the format understood by `METAQ/x/seconds`, which converts the passed string into a number of seconds.  So, you don't have to specify canonically-formatted times.  For example, you can specify 90:00 or 5400 instead of 1:30:00.
    
####`#METAQ LOG /absolute/path/to/log/file`
Write the running log of this task to the specified path.  

####`#METAQ PROJECT some.string.you.want.for.accounting.purposes`
METAQ doesn't worry about the task's project. However, it does log projects to `METAQ/jobs/${METAQ_JOB_ID}/resources`.  This is convenient if you have many comingled projects (or parts of projects) in the same `METAQ`.

It (probably) makes sense to have the string prefixed in order of generality (most specific detail last).

####`#METAQ MACHINE machine`
THIS CURRENTLY DOESN'T DO ANYTHING.

The intention is: If multiple machines can see the same `METAQ` but, for example, have different hardware (and thus incompatible binaries) you can nevertheless keep the `METAQ/todo` folder comingled.

# JOB SCRIPT STRUCTURE

Job scripts are bash scripts that get submitted to your batch scheduler (`SLURM`, `PBS`, etc.).  The structure of a job script is as follows.  Job scripts MUST be `bash` (sorry), because that is the language `METAQ` itself is written in.

The script below shows all the user-specifiable options.  For the optional options, their default values are shown as well.


```bash
#!/bin/bash
#MSUB -A [your account]
#MSUB -l nodes=10
#MSUB -l walltime=15:00
#MSUB [whatever other options]
#MSUB -o /absolute/path/to/metaq/log/%J.log
#MSUB -N metaq_job

# REQUIRED USER-SPECIFIED OPTIONS

METAQ=/full/path/to/metaq       # Specifies the full path to the metaq folder itself.
METAQ_JOB_ID=${SLURM_JOB_ID}    # Any string.  You don't have to use the batch scheduler ID, 
                                # but you should ensure that the METAQ_JOB_ID is unique.
METAQ_NODES=${SLURM_NNODES}     # Integer, which should be less than or equal to the nodes specified to the batch scheduler.
                                # But if it's less than, you're guaranteeing you're wasting resources.
METAQ_RUN_TIME=900              # Seconds, should match the above walltime=15:00.
                                # You may also specify times in the format for the #METAQ MIN_WC_TIME flag, [[HH:]MM:]SS.


# OPTIONAL USER-SPECIFIED OPTIONS, with their defaults

METAQ_GPUS=0                    # An integer describing how many GPUs are allocated to this job.
                                # How many GPUs to specify is a bit of a subtle business.  See below for more discussion.
METAQ_MAX_LAUNCHES=1048576      # An integer that limits the number of tasks that can be successfully launched.  Default is 2^20, essentially infinite.
METAQ_LOOP_FOREVER=false        # Bash booleans {true,false}.  Should you run out the wall clock?  
                                # If METAQ_LOOP_FOREVER is true then METAQ will continue to look for remaining tasks,
                                # even if it finds none and it is not waiting for any tasks to finish.
METAQ_SLEEPY_TIME=3             # Number of seconds to sleep before repeating the main task-attempting loop.
METAQ_MACHINE=machine           # Any string. Right now doesn't do anything, but it could in the future!
                                # Would interact with METAQ MACHINE flag.
METAQ_VERBOSITY=2               # How much detail do you want to see?
                                # Levels of detail are offset by tabbing 4 spaces.
                                
# ANYTHING ELSE YOU WANT TO DO BEFORE LAUNCHING.
# For example, you can have this script resubmit itself.
# Or, if you have a script for populating the METAQ/{todo,priority} folders, you can run it now.

# ATTACK THE QUEUE
source ${METAQ}/x/launch.sh     # ANYTHING BELOW HERE IS NOT GUARANTEED TO RUN!
                                # For example, if the tasks run out the wall clock time, METAQ/x/launch.sh never finishes.

# AND THAT IS ALL!
```

# MISCELLANEOUS

##What is meant by a "GPU" and a "NODE"?

THIS IS A SUBTLE BUSINESS.

On many machines there are only a few GPUs and many CPUs on a single physical node.
It may be possible to overcommit, meaning that you can run one binary on a few CPUs and the GPUs and another binary on the remaining CPUs.  
If you CANNOT overcommit (eg. on Titan), then you can forget about GPUs altogether and just worry about NODEs, and think of them as the physical nodes on the machine.

If you CAN overcommit (eg. on Surface), then potentially what you should mean by GPU is (one GPU and one controlling CPU), while a NODE is (#CPUS per node - #GPUs per node).  For example, on LLNL's GPU machine Surface each node has 2 GPUs and 16 CPUs.  So, from the point of view of `METAQ` there are 2 GPUs and 1 14-CPU node.  

However, it may be that your binary is smart and knows how make use of all the resources on the whole physical node at once.  In that case you can again forget about GPUs and just worry about NODEs.

If some of your tasks are smart and can use the whole node and some cannot, you need to be careful.  Because `METAQ` makes no promises about where the available NODEs and GPUs are.  It could be, for example, that there is 1 GPU free over HERE and a bunch of CPUs free over THERE and then it may not make sense to run a 1 NODE 1 GPU job.  In this case you should again think of NODES as representing full physical nodes (CPUs and GPUs) and simply be OK with wasting some of the resources some of the time.
    
So, to summarize: GPU is really a stand-in for a way to partition the physical node.  You should make sure your partition makes sense and is compatible between all your tasks.

# METAQ MONITORING

`METAQ` provides a number of small accessories to see what's going on.  

####`x/status`
Reports based on tasks' PROJECT flag what's in the `METAQ/{priority,todo,hold}` folders.

####`x/running`
Reports the current status of jobs in the working folder.  This only works if you have set up

####`x/reset`
WARNING WARNING WARNING

SERIOUSLY

HANDLE WITH CARE!
    
If your queue contains only work for one machine, this is perfectly fine.  
However, if `METAQ_JOB_RUNNING` (see below on interacting with the batch scheduler) could potentially miss the existence of a job then this command can wreck havoc.
This task looks in the working directory, and looks for abandoned work.  
If it finds work for a `METAQ_JOB_ID` that is no longer running, it moves the task scripts into the `METAQ/priority` folder and deletes the `METAQ/working/METAQ_JOB_ID` folder.

## INTERACTING WITH THE BATCH SCHEDULER

For some accessories, `METAQ` needs to know about your batch scheduler.

It always looks in the shell file (or symbolic link) `METAQ/x/batch.sh` for information about your batch scheduler.  Files for SLURM and PBS are provided.

If you use a different batch scheduler, then you can create your own file.  Here are the specifications:

```bash
#!/bin/bash

METAQ_BATCH_SCHEDULER="SCHEDULER_NAME"
    # A variable which indicates what batch scheduler you're using.  Currently unused, but could be used in the future.  Just set it for documentation's sake.
    # I imagine some day this information can be used to create job script files.

function METAQ_JOB_RUNNING {
    # JOB_ID --> STRING
    # A function that returns the empty string if the job does not exist.
    }

```

# REPORTS

Because it tabulates consumed resources and keeps track of the associated task files, I hope to be able to generate some smart reports.
As it stands, this is totally unimplemented.

# INSTALLATION

Simply `git clone` into any directory that is readable and writable from the supercomputing nodes.

You can perform a bare-bones test from the `METAQ` directory by running `x/demo.sh`.

Job scripts have some `/full/path/to/metaq`s that need to actually point to the `METAQ` directory.  Some accessories also point to the METAQ directory and need a simple path substitution:

- [ ] x/report
- [ ] x/reset
- [ ] x/running
- [ ] x/status



# KNOWN BUGS / COMPLAINTS

The business about NODEs and GPUs is more subtle than is ideal.  But without making METAQ substantially more complicated I don't know how to solve the issue.

Tasks in the `METAQ/priority` folder are only preferred at the beginning of a job.

