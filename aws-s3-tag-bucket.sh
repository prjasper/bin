#! /usr/bin/env bash
  
# usage
help() {
    cat <<EOF
Usage: ${NAME} [-h] [-d] [-e ENVIRONMENT] [-o OWNER] [-p PROFILE] BUCKET
Adds tags for Environment and Owner to the given BUCKET. If the bucket is already tagged with these
keys, the current values are overridden. Any other tags are maintained.
    -e the value to set for the Environment tag, by default "production"
    -o the value to set for the Owner tag, by default "technology"
    -d debug mode: display the aws command that would be run, without running it
    -p an AWS profile required to access the bucket
    -h display this help and exit 
Note: the jq program must be installed.
EOF
}

# program name
NAME=`basename $0`

# process options
DEBUG=
ENVIRONMENT=production
OWNER=technology
PROFILE=
while getopts "de:o:p:h" OPT; do
    case "$OPT" in
        e)
            ENVIRONMENT=${OPTARG}
            ;;
        o)
            OWNER=${OPTARG}
            ;;
        p)
            PROFILE=--profile=${OPTARG}
            ;;
        d)
            DEBUG=echo
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
  "TagSet": [
    {
      "Key": "Environment",
      "Value": "${ENVIRONMENT}"
    },
    {
      "Key": "Owner",
      "Value": "${OWNER}"
    }
  ]
}
ADDITIONAL

# get the current tags
aws ${PROFILE} s3api get-bucket-tagging --bucket ${BUCKET} 2>/dev/null > ${ORIGINAL}

# merge them
jq -s '{TagSet: (.[0].TagSet + .[1].TagSet) | map(select(.Key | startswith("aws:") | not)) | unique_by(.Key)}' \
    ${ADDITIONAL} ${ORIGINAL} > ${NEW}

# put them to the buckets
${DEBUG} aws ${PROFILE} s3api put-bucket-tagging --bucket ${BUCKET} --tagging file://${NEW}

if [[ ${DEBUG} = "echo" ]] ; then
    cat ${NEW}
fi

# clean up
rm -f ${ORIGINAL} ${ADDITIONAL} ${NEW}
