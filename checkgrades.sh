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

python3.6 listgrades.pyz "$user" "$pw" > grades.tsv.tmp
cat grades.tsv.tmp | sort | uniq > grades.tsv.new
rm -f grades.tsv.tmp

if ! diff -N grades.tsv grades.tsv.new >/dev/null 2>&1; then
    # grade files differ
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
    #diff -uN grades.tsv grades.tsv.new || true
    mv -f grades.tsv.new  grades.tsv
else
    rm grades.tsv.new
fi
