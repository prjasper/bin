#! /usr/bin/env bash
  
# usage
help() {
    cat <<EOF
Usage: ${NAME} [-h] [-d] [-p PROFILE] [-v VERSION] BUCKET [PREFIX]
Removes the delete markers from the given BUCKET and optional PREFIX with the optional
VERSION id. Objects expired at the same time through lifecycle rules share the same 
version id.
It's highly recommended that the PREFIX is specified to reduce the number of files
processed at a time.
And specifying the VERSION id will ensure that only the intended deletions are restored.
Note: this only works on versioned buckets, where the previous versions still exist!
    -d debug mode: display the aws command that would be run, without running it
    -p an AWS profile required to access the bucket
    -v the VERSION id for the delete markers to be removed
    -h display this help and exit 
EOF
}

# program name
NAME=`basename $0`

# process options
DEBUG=
PROFILE=
VERSION=
while getopts "dp:v:h" OPT; do
    case "$OPT" in
        d)
            DEBUG=echo
            ;;
        p)
            PROFILE=--profile=${OPTARG}
            ;;
        v)
            VERSION="?VersionId=='${OPTARG}'"
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
if [ $# -eq 1 ]; then
    BUCKET="$1"
    PREFIX=
elif [ $# -eq 2 ]; then
    BUCKET="$1"
    PREFIX="--prefix $2"
else
    help
    exit 1
fi

TMP=/tmp/${NAME}-$$.json

# iterate over batches of 1000 delete markers until done
while true; do
    # get the delete markers
    aws ${PROFILE} s3api list-object-versions --bucket ${BUCKET} ${PREFIX} \
        --query "{Objects:DeleteMarkers[${VERSION}]|[0:999].{VersionId:VersionId,Key:Key}}" > ${TMP}
    if [ $(wc -l ${TMP} | awk '{ print $1 }') -gt 3 ]; then
        # delete them
        ${DEBUG} aws ${PROFILE} s3api delete-objects --bucket ${BUCKET} --delete file://${TMP}

        if [[ ${DEBUG} = "echo" ]]; then
            cat ${TMP}
        fi

        # clean up
        rm -f ${TMP}
    else
        echo Done
        exit 0
    fi
done
