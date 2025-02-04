#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2021-2023 Tero Tervala <tero.tervala@unikie.com>
# SPDX-FileCopyrightText: 2021-2023 Unikie
# SPDX-FileCopyrightText: 2021-2023 Technology Innovation Institute (TII)

# Checks count of given field
function Check_count {
    local field
    local count
    local dest
    local allowmany

    field="$1"
    dest="$2"
    allowmany="${3:-0}"

    count="$(grep -c -e "^${field}:" "$dest" || true)"

    case "$count" in
    0)
        echo "ERROR: Missing ${field} field"
        return 1
    ;;
    1)
        return 0
    ;;
    *)
        if [ "$allowmany" == "0" ]; then
            echo "ERROR: Multiple ${field} fields (Only one required and allowed)"
            return 1
        else
            return 0
        fi
    ;;
    esac
}

function Exit_message {
    echo ""
    echo "Your commit message is not lost (yet), it's saved in the .git dir of the repo"
    echo "You probably can use something like this to edit your message:"
    echo "git commit -e --file=\$(git rev-parse --git-dir)/COMMIT_EDITMSG"
    echo ""
    exit 1
}

set -e

case "${1,,}" in
check-script)
    shellcheck "$0"
    bashate -i E006 "$0"
    echo "Nothing to complain"
    exit 1
;;
""|help|-h|--help)
    echo "This script is supposed to be called from the git commit-msg hook"
    echo ""
    echo "check-commit.sh COMMIT_MSG_FILE      Check commit message"
    echo "check-commit.sh check-script         Run shellcheck and bashate on the script itself"
    echo "check-commit.sh [help|-h|--help]     Show this help"
    echo ""
    exit 1
;;
esac

DEST="$1"

# Remove trailing spaces
sed -i 's/[[:space:]]*$//g' "$DEST"

# Remove preceding spaces from subject line
sed -i '1 s/^[[:space:]]*//' "$DEST"

# Find 'Jira-Id:' field case insensitively and replace with exact string 'Jira-Id: '
# Allow dashes, spaces, underscores and nothing between 'Jira' and 'Id'
# Remove extra spaces.
#sed -i 's/^[[:blank:]]*[jJ][iI][rR][aA][ _-]*[iI][dD][[:blank:]]*:[[:blank:]]*/Jira-Id: /g' "$DEST"

# Reformat Signed-off-by field
sed -i 's/^[[:blank:]]*[sS][iI][gG][nN][eE][dD][ _-]*[oO][fF][fF][ _-]*[bB][yY][[:blank:]]*:[[:blank:]]*/Signed-off-by: /g' "$DEST"

# Reformat Change-Id field
#sed -i 's/^[[:blank:]]*[cC][hH][aA][nN][gG][eE][ _-]*[iI][dD][[:blank:]]*:[[:blank:]]*/Change-Id: /g' "$DEST"

# Reformat Depends-On fields
#sed -i 's/^[[:blank:]]*[dD][eE][pP][eE][nN][dD][sS][ _-]*[oO][nN][[:blank:]]*:[[:blank:]]*/Depends-On: /g' "$DEST"

SUBJECT="$(head -n 1 "$DEST")"
SECONDLINE="$(head -n 2 "$DEST" | tail -n 1)"
BODYLINELEN="$(grep -v -e "^[[:blank:]]*#" "$DEST" | tail -n +2 | wc -L | cut -d ' ' -f 1)"

FAILED=
WARNED=

echo ""

if [ -z "$SUBJECT" ]; then
    echo "ERROR: Subject line is empty"
    FAILED=1
else
    if [ "${#SUBJECT}" -gt 50 ]; then
        echo "ERROR: Subject line is longer than 50 characters"
        FAILED=1
    fi
fi

if [ -n "$SECONDLINE" ]; then
    echo "ERROR: There is no empty line after subject line"
    FAILED=1
fi

if [ "$BODYLINELEN" -gt 72 ]; then
    echo "ERROR: Message body contains lines longer than 72 characters"
    FAILED=1
fi

if ! Check_count "Signed-off-by" "$DEST" 1; then
    FAILED=1
fi

#if ! Check_count "Jira-Id" "$DEST"; then
#    FAILED=1
#fi

#if ! Check_count "Change-Id" "$DEST"; then
#    FAILED=1
#fi

# If first word ends with "ing" or "ed" it is suspected that subject is not in imperative mood.
# If there is a colon (:) in the subject then check the first word after colon. (Allows e.g. a filename at the start)
# As the rule is not perfect, this will only give a warning and confirmation prompt.
if printf "%s" "$SUBJECT" | grep -q -e '\(^.*\?:[[:blank:]]*[^[:blank:]]*\([eE][dD]\|[iI][nN][gG]\)[[:blank:]]\|^[^[:blank:]]*\([eE][dD]\|[iI][nN][gG]\)[[:blank:]]\)'; then
    echo "WARNING: Subject might not be in imperative (commanding) mood"
    WARNED=1
fi

# If first letter of first word is not upper case or if first letter of first word after colon (:) is not upper case
# Incorrect capitalization is suspected. As the rule might not be perfect, this only gives a warning and confirmation prompt.
if printf "%s" "$SUBJECT" | grep -q -e '\(^.*\?:[[:blank:]]*[a-z].*$\|^[a-z][^:]*$\)'; then
    echo "WARNING: Subject capitalization might not be correct"
    WARNED=1
fi

if [ -n "$FAILED" ]; then
    Exit_message
fi

# Grab list of Jira-Ids given
#JIRAIDS="$(grep -e "^Jira-Id:" "$DEST")"

# Grab Signed-off-lines
SIGNOFF="$(grep -e "^Signed-off-by:" "$DEST")"

# Grab Change-Id line
#CHANGEID="$(grep -e "^Change-Id:" "$DEST")"

# Grab Depends-On lines
#DEPSONS="$(grep -e "^Depends-On:" "$DEST" || true)"

# Delete the Jira-Id: -line
#sed -i '/^Jira-Id:/d' "$DEST"

# Delete the Signed-off-by: -line
sed -i '/^Signed-off-by:/d' "$DEST"

# Delete the Change-Id: -line
#sed -i '/^Change-Id:/d' "$DEST"

# Delete the Depends-On: -lines
#sed -i '/^Depends-On:/d' "$DEST"

# Delete leading and trailing empty lines
sed -i -e '/./,$!d' -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$DEST"

{
    # Add an empty line
    printf "\n"
    # Add Jira-Id line
    #printf "\n%s\n" "$JIRAIDS"
    # Add Signed-off-by lines
    printf "%s\n" "$SIGNOFF"
    # Add Change-Id line
    #printf "%s\n" "$CHANGEID"

    #if [ -n "$DEPSONS" ]; then
    #    # Add Depends-On lines
    #    printf "%s\n" "$DEPSONS"
    #fi
} >> "$DEST"

if [ -n "$WARNED" ]; then
    STR=
    while [ -z "$STR" ]; do
        echo -e "\n${SUBJECT}\n"
        echo -n "Are you sure you want to continue with this? (Y/N): "
        read -r STR < /dev/tty
        case "$STR" in
        y|Y)
            exit 0
        ;;
        n|N)
            echo "Aborted"
            Exit_message
        ;;
        *)
            STR=
        ;;
        esac
    done
fi
