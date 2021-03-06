#!/bin/bash

###
### Perform a bunch of setup
###

function rand {
    mod=$1
    if [[ -z "$mod" ]]; then
        mod=150
    fi
    echo "${RANDOM}" | awk -v m=$mod '{print 1+$1%m}'
}

mkdir -p todo working finished jobs log priority hold

if ! ls todo/* 2>/dev/null; then
    echo "Your todo folder is empty, which is good for demonstration purposes."
else
    echo "You have things in your todo folder."
    echo "Demo is aborting."
    exit

fi

for t in {0..7}; do
    echo "#!/bin/bash
#METAQ NODES $(rand 5)
#METAQ GPUS $(rand 8)
#METAQ MIN_WC_TIME $(rand 150)
#METAQ PROJECT metaq.demo

echo \"working hard...\"
sleep $(rand 40)            # The 'hard work' is a sham!
echo \"done!\"

" > todo/metaq.example.task.$t.sh
chmod +x todo/metaq.example.task.$t.sh
done


###
### Do what a run script would do:
###

METAQ=$(pwd)
METAQ_JOB_ID=metaq.demo.job.$RANDOM
METAQ_NODES=16  # It's a lie!
METAQ_GPUS=32   # It's a lie!
METAQ_SIMULTANEOUS_TASKS=4
METAQ_MACHINE=mq.test.machine
METAQ_RUN_TIME=600
METAQ_VERBOSITY=5
METAQ_MAX_NODES=1
METAQ_MAX_GPUS=2
# METAQ_SORT_TASKS=shuf

METAQ_SLEEP_AFTER_LAUNCH=5

source x/launch.sh
