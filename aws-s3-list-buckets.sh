#! /usr/bin/env bash
 
# usage
help() {
    cat <<EOF
Usage: ${NAME} [-h] [-p PROFILE] [-c] [-d C] [-j C] [-s] [-t] [-x] [-i] [-a TAG] [-e] [-o] [-v] [-1|-2|-3] [BUCKET ...]
Lists the given S3 BUCKETs (defaults to all buckets) from the given PROFILE (defaults to the
current profile).
    -p an AWS profile required to access the buckets
    -c print column headings for the report
    -d use the given character C to separate columns (default is the tab character)
    -j use the given character C to start and end each line - useful for JIRA tables (default none)
    -s report the size in GB of the bucket
    -t report the days at which the first and second transitions occur in the bucket's default
       lifecycle rule
    -x report the expiration in days from each bucket's default lifecycle rule
    -i report the AbortIncompleteMultipartUpload days from each bucket's default lifecycle rule
    -a report the value of the named TAG
    -e report the bucket environment from the Environment tag
    -o report the bucket owner from the Owner tag
    -v report whether the bucket has versioning enabled
    -1 report the top-level "folders" in each bucket
    -2 report the second-level "folders" in each bucket
    -3 report the third-level "folders" in each bucket
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
TAGS=()
VERSIONING=0
FOLDERS=0
while getopts "p:cd:j:stxia:eov123h" OPT; do
    case "$OPT" in
        p)
            PROFILE="--profile=${OPTARG}"
            PPROFILE="-p ${OPTARG}"
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
        a)
            TAGS+=("${OPTARG}")
            ;;
        e)
            TAGS+=("Environment")
            ;;
        o)
            TAGS+=("Owner")
            ;;
        v)
            VERSIONING=1
            ;;
        1)
            FOLDERS=1
            ;;
        2)
            FOLDERS=2
            ;;
        3)
            FOLDERS=3
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
    BUCKETS=$(aws ${PROFILE} s3api list-buckets --query 'Buckets[].{Name:Name}' --output text)
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
    for TAG in "${TAGS[@]}"; do
        printf "%-15s${DELIMITER}${STARTEND}" "${TAG}"
    done
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
    REGION=$(aws ${PROFILE} s3api get-bucket-location --bucket ${BUCKET} --query 'LocationConstraint' --output text | \
        awk '{sub(/None/,"us-east-1")}; 1')
    if [ ${SIZE} -eq 1 ]; then
        GB=$(aws ${PROFILE} cloudwatch get-metric-statistics --namespace AWS/S3 --start-time "${YESTERDAY}" \
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
        RESULT=$(aws ${PROFILE} s3api get-bucket-lifecycle-configuration --bucket ${BUCKET} --region ${REGION} \
            --query 'Rules[?Filter.Prefix==``||Filter.Prefix==`/`||Prefix==``||Prefix==`/`].{ATD:Transitions[0].Days,BTS:Transitions[0].StorageClass,CTD:Transitions[1].Days,DTS:Transitions[1].StorageClass,EE:Expiration.Days,FI:AbortIncompleteMultipartUpload.DaysAfterInitiation}' \
            --output text 2>/dev/null)
        transitions ${TRANSITIONS} "${RESULT}"
        days ${EXPIRATION} "${RESULT}" 5
        days ${INCOMPLETE} "${RESULT}" 6
    fi
    for TAG in "${TAGS[@]}"; do
        VALUE=$(aws ${PROFILE} s3api get-bucket-tagging --bucket ${BUCKET} --region ${REGION} \
            --query "TagSet[?Key==\`${TAG}\`].{V:Value}" --output text 2>/dev/null)
        if [ ${#VALUE} -gt 0 ]; then
            printf "%-15s" "${VALUE}"
        else
            printf "%-15s" "-"
        fi
        echo -n -e "${DELIMITER}"
    done
    if [ ${VERSIONING} -eq 1 ]; then
        ENABLED=$(aws ${PROFILE} s3api get-bucket-versioning --bucket ${BUCKET} --region ${REGION} --output text 2>/dev/null)
        if [[ ${ENABLED} == "Enabled" ]]; then
            echo -n "Versioned"
        else
            printf "%-15s" "-"
        fi
        echo -n -e "${DELIMITER}"
    fi
    echo -n ${BUCKET}
    echo ${STARTEND}
    if [ ${FOLDERS} -ge 1 ]; then
        for FOLDER1 in $(aws ${PROFILE} s3 ls "${BUCKET}" | awk '{ print $2 }') ; do
            if [ ${FOLDERS} -ge 2 ]; then
                for FOLDER2 in $(aws ${PROFILE} s3 ls "${BUCKET}/${FOLDER1}" | awk '{ print $2 }') ; do
                    if [ ${FOLDERS} -ge 3 ]; then
                        for FOLDER3 in $(aws ${PROFILE} s3 ls "${BUCKET}/${FOLDER1}${FOLDER2}" | awk '{ print $2 }') ; do
                            echo -e "${DELIMITER}${FOLDER1}${FOLDER2}${FOLDER3}"
                        done
                    else
                        echo -e "${DELIMITER}${FOLDER1}${FOLDER2}"
                    fi
                done
            else
                echo -e "${DELIMITER}${FOLDER1}"
            fi
        done
    fi
done
