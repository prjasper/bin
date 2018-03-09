#!/usr/bin/env bash

usage() {
    NAME=`basename $0`
    cat <<EOF
Usage: ${NAME} [-r|-c|-s|-m|-h] [-d|-t] [-p PURPOSE] [-g] DATE [COMMENT]
Run the Reach & Overlap pipeline for the given DATE, adding an optional COMMENT to the name.
The current directory should be the base of the krux-spark-marketer repo.
The "-r" option calculates regular site reach and overlaps. This is the default.
The "-c" option calculates campaign reach and overlaps.
The "-s" option calculates segment reach and overlaps using S3 user-segment data.
The "-m" option calculates segment reach and overlaps using the unreliable marketer impressions.
The "-n" option calculates all segment reach and overlaps for an organization simultaneously, which can cause out-of-memory conditions.
The "-d" option runs for daily clients only. The default is to run weekly clients only.
The "-t" option runs for retry clients only and sets the Purpose tag to "rerun".
The "-p" option sets the Purpose tag to the given PURPOSE, which must be one of "scheduled", "manual", "backfill", "rerun" or "test".
The "-g" option generates the configuration without running it.
The "-h" option prints this usage message.
EOF
}

TYPE=Site
GENERATE=0
DAILY=
PURPOSE=manual
while getopts "crsmndtp:gh" OPT; do
    case "$OPT" in
        r)
            TYPE=Site
            ;;
        c)
            TYPE=Campaign
            ;;
        s)
            TYPE=Segment
            ;;
        m)
            TYPE=MarketerImpressionsSegment
            ;;
        n)
            TYPE=SimultaneousSegment
            ;;
        d)
            DAILY=Daily
            ;;
        t)
            DAILY=Retry
            PURPOSE=rerun
            ;;
        p)
            case ${OPTARG} in
                scheduled|manual|backfill|rerun|test)
                    PURPOSE=${OPTARG}
                    ;;
                *)
                    echo "Invalid PURPOSE: ${OPTARG}" >&2
                    usage >&2
                    ;;
            esac
            PURPOSE=${OPTARG}
            ;;
        :)
            echo "Option -${OPTARG} requires an argument" >&2
            exit 1
            ;;
        g)
            GENERATE=1
            ;;
        h)
            usage
            exit 0
            ;;
        '?')
            usage >&2
            exit 1
            ;;
    esac
done
shift "$((OPTIND-1))"

# check arguments
if [ $# -lt 1 -o $# -gt 2 ]; then
    usage
    exit 1
fi

DATE="$1"
COMMENT="$2"

if [ ${GENERATE} -eq 1 ]; then
    COMMAND=generate
else
    COMMAND="create --activate --force --name ReachOverlap${DAILY}${TYPE}${COMMENT}Test_${DATE}_$$ --start ${DATE} --times 1"
fi
export KRUX_ENVIRONMENT=prod
sbt <<EOF
project marketerAnalytics
run-main com.krux.marketer.reachoverlap.pipeline.ReachOverlap${DAILY}${TYPE}Pipeline ${COMMAND} --tags:Purpose=${PURPOSE}
exit
EOF
