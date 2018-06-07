#! /usr/bin/env bash
 
# usage
help() {
    cat <<EOF
Usage: ${NAME} [-h] [-p PROFILE] [-c] [-d CHARACTER] [-j CHARACTER] [-s] [-t] [-x] [-i] [-e] [-o] [-v] [BUCKET ...]
Lists the given S3 BUCKETs (defaults to all buckets) from the given PROFILE (defaults to the
current profile).
    -p an AWS profile required to access the buckets
    -c print column headings for the report
    -d use the given CHARACTER to separate columns (default is the tab character)
    -j use the given character to start and end each line - useful for JIRA tables (default none)
    -s report the size in GB of the bucket
    -t report the days at which the first and second transitions occur in the bucket's default
       lifecycle rule
    -x report the expiration in days from each bucket's default lifecycle rule
    -i report the AbortIncompleteMultipartUpload days from each bucket's default lifecycle rule
    -e report the bucket environment from the Environment tag
    -o report the bucket owner from the Owner tag
    -v report whether the bucket has versioning enabled
    -h display this help and exit 
Note: "None" is displayed if the rule does not contain the setting and "-" if there is no rule.
EOF
}

# program name
NAME=`basename $0`

# process options
PROFILE=
PPROFILE=
COLUMN=0
DELIMITER="\t"
STARTEND=
SIZE=0
TRANSITIONS=0
EXPIRATION=0
INCOMPLETE=0
ENVIRONMENT=0
OWNER=0
VERSIONING=0
while getopts "p:cd:j:stxieovh" OPT; do
    case "$OPT" in
        p)
            PROFILE=--profile=${OPTARG}
            PPROFILE=-p ${OPTARG}
            ;;
        c)
            COLUMN=1
            ;;
        d)
            DELIMITER="${OPTARG}"
            ;;
        j)
            STARTEND="${OPTARG}"
            ;;
        s)
            SIZE=1
            TODAY=$(gdate +%Y-%m-%d)
            YESTERDAY=$(gdate +%Y-%m-%d --date=yesterday)
            ;;
        t)
            TRANSITIONS=1
            ;;
        x)
            EXPIRATION=1
            ;;
        i)
            INCOMPLETE=1
            ;;
        e)
            ENVIRONMENT=1
            ;;
        o)
            OWNER=1
            ;;
        v)
            VERSIONING=1
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
    BUCKETS=$(aws s3api list-buckets --query 'Buckets[].{Name:Name}' --output text)
fi

# display the transitions to S3-IA and Glacier
transitions() {
    DAYS=$(echo ${2} | cut -d ' ' -f 1)
    STORAGE=$(echo ${2} | cut -d ' ' -f 2)
    if [[ ${STORAGE} == 'STANDARD_IA' && ${#DAYS} > 0 ]]; then
        echo -n ${DAYS}
    else
        echo -n "-"
    fi
    echo -n -e "${DELIMITER}"
    if [[ ${STORAGE} == 'GLACIER' && ${#DAYS} > 0 ]]; then
        echo -n ${DAYS}
    else
        DAYS=$(echo ${2} | cut -d ' ' -f 3)
        STORAGE=$(echo ${2} | cut -d ' ' -f 4)
        if [[ ${STORAGE} == 'GLACIER' && ${#DAYS} > 0 ]]; then
            echo -n ${DAYS}
        else
            echo -n "-"
        fi
    fi
    echo -n -e "${DELIMITER}"
}

# display the days for each option
days() {
    if [ ${1} -eq 1 ]; then
        DAYS=$(echo ${2} | cut -d ' ' -f ${3})
        if [ ${#DAYS} -gt 0 ]; then
            echo -n ${DAYS}
        else
            echo -n "-"
        fi
        echo -n -e "${DELIMITER}"
    fi
}


if [ ${COLUMN} -eq 1 ]; then
    # print the column headings
    tput bold
    echo -n ${STARTEND}${STARTEND}
    if [ ${SIZE} -eq 1 ]; then
        echo -n -e "Size GB${DELIMITER}${STARTEND}"
    fi
    if [ ${TRANSITIONS} -eq 1 ]; then
        echo -n -e "IA${DELIMITER}Glacier${DELIMITER}${STARTEND}"
    fi
    if [ ${EXPIRATION} -eq 1 ]; then
        echo -n -e "Exp${DELIMITER}${STARTEND}"
    fi
    if [ ${INCOMPLETE} -eq 1 ]; then
        echo -n -e "Inc${DELIMITER}${STARTEND}"
    fi
    if [ ${ENVIRONMENT} -eq 1 ]; then
        echo -n -e "Environment${DELIMITER}${STARTEND}"
    fi
    if [ ${OWNER} -eq 1 ]; then
        echo -n -e "Owner   ${DELIMITER}${STARTEND}"
    fi
    if [ ${VERSIONING} -eq 1 ]; then
        echo -n -e "Versioning${DELIMITER}${STARTEND}"
    fi
    echo -n Bucket
    echo ${STARTEND}${STARTEND}
    tput sgr0
fi

# list the buckets from the given profile one per line
for BUCKET in ${BUCKETS} ; do
    echo -n ${STARTEND}
    REGION=$(aws s3api get-bucket-location --bucket ${BUCKET} --query 'LocationConstraint' --output text | \
        awk '{sub(/None/,"us-east-1")}; 1')
    if [ ${SIZE} -eq 1 ]; then
        GB=$(aws cloudwatch get-metric-statistics --namespace AWS/S3 --start-time "${YESTERDAY}" \
            --end-time "${TODAY}" --period 86400 --statistics Average --region ${REGION} --metric-name BucketSizeBytes \
            --dimensions Name=BucketName,Value="${BUCKET}" Name=StorageType,Value=StandardStorage \
            --query 'Datapoints[].Average[]' --output text | sed 's/e+/*10^/')
        if [ ${#GB} -gt 0 ]; then
            echo -n $(echo "${GB} / 1024 / 1024 / 1024" | bc)
        else
            echo -n -e "Empty"
        fi
        echo -n -e "${DELIMITER}"
    fi
    if [ ${TRANSITIONS} -eq 1 -o ${EXPIRATION} -eq 1 -o ${INCOMPLETE} -eq 1 ]; then
        RESULT=$(aws s3api get-bucket-lifecycle-configuration --bucket ${BUCKET} --region ${REGION} \
            --query 'Rules[?Filter.Prefix==``||Filter.Prefix==`/`||Prefix==``||Prefix==`/`].{ATD:Transitions[0].Days,BTS:Transitions[0].StorageClass,CTD:Transitions[1].Days,DTS:Transitions[1].StorageClass,EE:Expiration.Days,FI:AbortIncompleteMultipartUpload.DaysAfterInitiation}' \
            --output text 2>/dev/null)
        transitions ${TRANSITIONS} "${RESULT}"
        days ${EXPIRATION} "${RESULT}" 5
        days ${INCOMPLETE} "${RESULT}" 6
    fi
    if [ ${ENVIRONMENT} -eq 1 ]; then
        TAGS=$(aws ${PROFILE} s3api get-bucket-tagging --bucket ${BUCKET} --region ${REGION} \
            --query 'TagSet[?Key==`Environment`].{E:Value}' --output text 2>/dev/null)
        if [ ${#TAGS} -gt 0 ]; then
            printf "%-15s" "${TAGS}"
        else
            printf "%-15s" "-"
        fi
        echo -n -e "${DELIMITER}"
    fi
    if [ ${OWNER} -eq 1 ]; then
        TAGS=$(aws ${PROFILE} s3api get-bucket-tagging --bucket ${BUCKET} --region ${REGION} \
            --query 'TagSet[?Key==`Owner`].{O:Value}' --output text 2>/dev/null)
        if [ ${#TAGS} -gt 0 ]; then
            printf "%-15s" "${TAGS}"
        else
            printf "%-15s" "-"
        fi
        echo -n -e "${DELIMITER}"
    fi
    if [ ${VERSIONING} -eq 1 ]; then
        ENABLED=$(aws ${PROFILE} s3api get-bucket-versioning --bucket ${BUCKET} --region ${REGION} --output text 2>/dev/null)
        if [[ ${ENABLED} == "Enabled" ]]; then
            echo -n "Versioned"
        else
            printf "%-9s" "-"
        fi
        echo -n -e "${DELIMITER}"
    fi
    echo -n ${BUCKET}
    echo ${STARTEND}
done
