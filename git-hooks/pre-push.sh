#!/usr/bin/env bash
# prevent push to remote master branch

NAME=$(basename $0)

while read local_ref local_sha remote_ref remote_sha ; do
    if [ "$remote_ref" = "refs/heads/master" ]; then
        echo "${NAME} hook: cannot push to remote master branch"
        exit 1
    fi
done

# chain pre-commit hooks if this hook is a global hook (via core.hooksPath) and there also exists a repo-specific hook
if [[ -f ".git/hooks/${NAME}" ]]; then
    type realpath >/dev/null 2>&1 || \
        { echo >&2 "NOTE: realpath is required to chain to the repo-specific ${NAME} hook"; exit 0; }
    if [[ "${BASH_SOURCE[0]}" != "$(realpath ".git/hooks/${NAME}")" ]]; then
        .git/hooks/${NAME}
        exit $?
    fi
fi

echo "${NAME} hook: OK"

exit 0
