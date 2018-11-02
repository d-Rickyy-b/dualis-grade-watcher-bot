#!/bin/sh

set -eu
cd "$(dirname "$0")"

### CONFIG
. ./config.inc.sh

### ACTUAL CODE

# fixup locale for cron job
export LANG="en_US.UTF-8"
export LC_CTYPE="en_US.UTF-8"
export LC_COLLATE="en_US.UTF-8"
export LC_MESSAGES="en_US.UTF-8"
export LC_NAME="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

python3 ./dualis.py "$user" "$pw" > grades.tsv.tmp
cat grades.tsv.tmp | sort | uniq > grades.tsv.new
rm -f grades.tsv.tmp

if ! diff -N grades.tsv grades.tsv.new >/dev/null 2>&1; then
    # grade files differ
    count=$(cat grades.tsv | wc -l)
    countNew=$(cat grades.tsv.new | wc -l)

    # Exit if the amount of grades = 0
    if [[ $countNew -eq 0 ]]; then
        exit 1
    fi

    # Exit if there are less grades than before. It's a common Dualis error
    if [[ $countNew -lt $count ]]; then
        echo -e "Count new is smaller than old count: $countNew | $count"
        echo -e "grades.tsv: $(cat grades.tsv)"
        echo -e "grades.tsv.new: $(cat grades.tsv.new)"
        exit 1
    fi

    grades="$(diff -b -U0 -N grades.tsv grades.tsv.new)"
    gradesMsg=$(printf "%s" "$grades" | sed -e '1,3d' | awk -F "\t" '{$2=$3="";print $0}')

    for to in $mailto; do
        (
            printf 'To: %s\n' "$to"
            printf 'Subject: Grade Report Modified\n'
            printf 'Content-Type: text/plain; charset=UTF-8\n'
            printf 'From: %s\n' "$mailfrom"
            printf '\n'
            diff -b -U0 -N grades.tsv grades.tsv.new
        ) | /usr/sbin/sendmail -oi -t
    done
    for to in $mailto_nogrades; do
        (
            printf 'To: %s\n' "$to"
            printf 'Subject: DUALIS Grade Report Modified\n'
            printf 'Content-Type: text/plain; charset=UTF-8\n'
            printf 'From: %s\n' "$mailfrom"
            printf '\n'
            printf 'Look! I even generated a diff for you!\n\n'
            printf 'Your friendly grade watcher bot\n\n'
            diff -b -U0 -N grades.tsv grades.tsv.new | awk -F'\t' 'BEGIN { OFS=FS } $5 != "" && $5 != "noch nicht gesetzt" { $5="<NOTE VERSTECKT>";} { print; }'
        ) | /usr/sbin/sendmail -oi -t
    done

    # If you want to getnotified via Telegram, just create a bod and add the token here
    # telegramToken=""
    # chat_id=""

    # Send message without grade content
    # curl -X POST "https://api.telegram.org/bot$telegramToken/sendMessage" -d chat_id="$chat_id" -d "text=Neue Noten sind online!"

    # Send message with grades
    # curl -X POST "https://api.telegram.org/bot$telegramToken/sendMessage" -d chat_id="$chat_id" -d "text=$(printf "Neue Noten sind online! \n%s" "$gradesMsg")"

    mv -f grades.tsv.new  grades.tsv
else
    rm grades.tsv.new
fi
