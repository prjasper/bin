#! /usr/bin/env bash
  
# usage
help() {
    cat <<EOF
Usage: ${NAME} [-h] [-d] [-p PROFILE] [-l LIMIT] BUCKET
Adds a LIMIT in days to the given BUCKET's lifecycle rules after which to clean up incomplete
multipart uploads.
    -d debug mode: display the aws command that would be run, without running it
    -p an AWS profile required to access the bucket
    -l the LIMIT in days from the start of the upload after which to clean up (default: 7)
    -h display this help and exit 
Note: the jq program must be installed.
EOF
}

# program name
NAME=`basename $0`

# process options
DEBUG=
PROFILE=
LIMIT=7
while getopts "dp:l:h" OPT; do
    case "$OPT" in
        d)
            DEBUG=echo
            ;;
        p)
            PROFILE=--profile=${OPTARG}
            ;;
        l)
            LIMIT=${OPTARG}
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
if [ $# -ne 1 ]; then
    help
    exit 1
fi

# arguments
BUCKET="$1"

ORIGINAL=/tmp/${NAME}-original-$$.json
ADDITIONAL=/tmp/${NAME}-additional-$$.json
NEW=/tmp/${NAME}-new-$$.json

cat >${ADDITIONAL} <<ADDITIONAL
{
  "Rules": [
    {
      "ID": "PruneIncompleteMultipartUpload",
      "Prefix": "",
      "Status": "Enabled",
      "AbortIncompleteMultipartUpload": {
        "DaysAfterInitiation": ${LIMIT}
      }
    }
  ]
}
ADDITIONAL

# get the current lifecycle rules
# gives an error message if it doesn't exist, but that doesn't prevent this script form working
aws ${PROFILE} s3api get-bucket-lifecycle-configuration --bucket ${BUCKET} 2>/dev/null > ${ORIGINAL}

# merge them
jq -s '{Rules: (.[0].Rules + .[1].Rules) | unique_by(.ID)}' \
    ${ADDITIONAL} ${ORIGINAL} > ${NEW}

# put them to the buckets
# gives an error message if a rule with the same name exists already
${DEBUG} aws ${PROFILE} s3api put-bucket-lifecycle-configuration --bucket ${BUCKET} --lifecycle-configuration file://${NEW}

if [[ ${DEBUG} = "echo" ]]; then
    cat ${NEW}
fi

# clean up
rm -f ${ORIGINAL} ${ADDITIONAL} ${NEW}
