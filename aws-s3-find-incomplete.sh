#! /usr/bin/env bash
  
# usage
help() {
    cat <<EOF
Usage: ${NAME} [-h] [-p PROFILE] [-e EXCLUDE] [BUCKET ...]
Finds any incomplete multipart uploads in the given BUCKETs (defaults to all
buckets) from the given PROFILE (defaults to the current profile). Note that
this includes uploads that may still be in progress.
    -p an AWS profile required to access the buckets
    -e exclude any uploads where the regular expression EXCLUDE matches its key
    -h display this help and exit 
Example: ${NAME} -e "2018-04-(29|30)" krux-tables
List all the incomplete multipart uploads that include neither of the given dates in
their key names.
EOF
}

# count the number of tokens in the argument
count() { echo $#; }

# program name
NAME=`basename $0`

# process options
PROFILE=
PPROFILE=
while getopts "p:e:h" OPT; do
    case "$OPT" in
        p)
            PROFILE=--profile=${OPTARG}
            PPROFILE=-p ${OPTARG}
            ;;
        e)
            EXCLUDE=${OPTARG}
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

# find buckets
if [ $# -gt 0 ]; then
    BUCKETS=$*
else
    BUCKETS=$(aws-s3-list-buckets ${PPROFILE})
fi

# process each bucket
TOTAL=0
for BUCKET in ${BUCKETS} ; do 
    if [ $(count ${BUCKETS}) -gt 1 ]; then
        echo "${BUCKET}:"
    fi
    PARTS=$(aws s3api list-multipart-uploads ${PROFILE} --bucket ${BUCKET} \
        --query 'Uploads[*].{Key:Key,UploadId:UploadId}' --output text)
    if [ "${PARTS}" != "None" ]; then
        IFS=$'\n'
        for PART in ${PARTS} ; do
            KEY=$(echo ${PART} | cut -f 1)
            if [ -z ${EXCLUDE+x} ] || [[ ! "${KEY}" =~ ${EXCLUDE} ]]; then
                ID=$(echo ${PART} | cut -f 2)
                DETAILS=$(aws s3api list-parts ${PROFILE} --bucket ${BUCKET} --key "${KEY}" --upload-id ${ID}) 
                if echo ${DETAILS} | fgrep -q '"Size":' ; then
                    SIZE=$(echo ${DETAILS} | fgrep '"Size":' | egrep -o '[0-9]+' | awk '{SUM += $1} END {print SUM}')
                    ((TOTAL+=${SIZE}))
                    MB=$(echo "${SIZE} / 1024 / 1024" | bc)
                    echo -e "${MB}MB\t${KEY}"
                    # uncomment below to delete instead of printing the size
                    #aws s3api abort-multipart-upload ${PROFILE} --bucket ${BUCKET} --key "${KEY}" --upload-id ${ID}
                fi
            fi
        done
    fi
done

# print the total size
echo $(echo "${TOTAL} / 1024 / 1024 / 1024" | bc)GB total
