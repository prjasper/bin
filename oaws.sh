#!/usr/bin/env bash

## Open an aws object details by given id
## currently for mac only
## REQUIRES: aws CLI tool

#usage
help() {
    NAME=`basename $0`
    cat <<EOF
Usage: ${NAME} [-s] [-h] AWS_OBJECT_ID
Open the given AWS object in the default browser.
The "-s" option forces the object to open in Safari.
The "-h" option prints this message.
Options can be read from a file called ".oaws" in the home directory.
For example, "APPLICATION=/Applications/Safari.app" or
"AWS_DEFAULT_REGION=us-west-1".
EOF
}

# default
APPLICATION=

if [[ -r ~/.oaws ]]; then
    # override default from a file
    eval `grep -e '^[A-Za-z0-9_]*=.*$' ~/.oaws`
fi

while getopts "sh" OPT; do
    case "$OPT" in
        s)
            APPLICATION="/Applications/Safari.app"
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

if [ $# -ne 1 ]; then
    help
    exit 1
fi

aws_id=$1; shift

AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-us-east-1}

if [[ $aws_id == df-* ]]; then
    obj_detail_url="https://console.aws.amazon.com/datapipeline/home?region=${AWS_DEFAULT_REGION}#ExecutionDetailsPlace:pipelineId=${aws_id}&show=latest"
elif [[ $aws_id == j-* ]]; then
    obj_detail_url="https://console.aws.amazon.com/elasticmapreduce/home?region=${AWS_DEFAULT_REGION}#cluster-details:${aws_id}"
elif [[ $aws_id == i-* ]]; then
    obj_detail_url="https://console.aws.amazon.com/ec2/v2/home?region=${AWS_DEFAULT_REGION}#Instances:search=${aws_id};sort=desc:instanceState"
else
    IFS=$'\n'
    matches=( $(aws datapipeline list-pipelines | grep -i -B 1 $aws_id) )

    if [[ ${#matches[@]} == 0 ]]; then
        echo "No matches found"
        exit 1
    elif [[ ${#matches[@]} == 2 ]]; then
        echo "Found one match:"
        aws_id=`echo ${matches[0]} | grep -o 'df-[[:alnum:]]*'`
        obj_detail_url="https://console.aws.amazon.com/datapipeline/home?region=${AWS_DEFAULT_REGION}#ExecutionDetailsPlace:pipelineId=${aws_id}&show=latest"
    else
        echo "Multiple matches:"
        echo ${matches[@]} | sed 's/--/\'$'\n/g' | cut -d\" -f 4,8 | tr '"' '\t' | sort -k 2
        exit 1
    fi
fi

echo "Opening $obj_detail_url in your browser..."
open ${APPLICATION:+-a $APPLICATION} $obj_detail_url
exit 1
