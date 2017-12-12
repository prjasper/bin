#! /usr/bin/env /bin/bash

#usage
help() {
    NAME=`basename $0`
    cat <<EOF
Usage: ${NAME} [-g] [-h] CLASS START [END]
Run the given pipeline class in Hyperion to backfill the data for the given date
range from START to END. If only START is given, run for just that date.
The date is the day that the pipeline is run for -- this usually means that the
data is processed for the preceeding day. Remember to add one more day to the END.
If option "-g" is specified the pipeline configuration is generated, but not
run. This is useful for testing before running the pipeline in earnest.
The "-h" option prints this message.
Example: ${NAME} com.krux.dataprocessing.pipeline.datasentry.PageViewsLoader 2017-01-02 2017-02-02
Run the PageViewsLoader pipeline to process data for the whole of January 2017.
EOF
}

# process options
GENERATE=0
while getopts "gh" OPT; do
    case "$OPT" in
        g)
            GENERATE=1
            ;;
        h)
            help
            exit 0
            ;;
        '?')
            help >&2
            exit 1
            ;;
    esac
done
shift "$((OPTIND-1))"

# check arguments
if [ $# -eq 2 ]; then
    END=$2
    ENDARG="--times 1"
elif [ $# -eq 3 ]; then
    END=$3
    ENDARG="--until $3"
else
    help
    exit 1
fi

# arguments
CLASS=$1
START=$2

# make the command
if [ ${GENERATE} -eq 1 ]; then
    COMMAND=generate
else
    COMMAND="create --activate --force \
        --start ${START} ${ENDARG} \
        --name \"${CLASS} Backfill ${START} to ${END}\""
fi

# build the pipeline
export KRUX_ENVIRONMENT=prod
sbt <<SBT
compile
run-main ${CLASS} ${COMMAND}
exit
SBT

