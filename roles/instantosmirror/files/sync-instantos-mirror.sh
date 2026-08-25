#!/bin/sh
# Mirror the instantOS pacman repository from the canonical CI-published
# source (https://instantos.io/packages/) into timestamped snapshots.
#
# Every run downloads into a fresh snapshot seeded from the currently
# served one (so wget timestamping only fetches changes), verifies that
# the snapshot is self-consistent and only then atomically repoints the
# `current` symlink. Caddy serves <data_dir>/current, so a failed,
# partial or broken upstream never affects what is being served.
set -eu

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

upstream_url="${1:-https://instantos.io/packages/}"
data_dir="${2:-/data/instantos-mirror}"
keep_snapshots="${3:-4}"

snapshots_dir="$data_dir/snapshots"
current_link="$data_dir/current"
lock_file="$data_dir/sync.lock"
log_file="$data_dir/sync.log"

log() {
    printf '%s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*" >>"$log_file"
}

fail() {
    log "ERROR: $* - keeping previous snapshot"
    exit 1
}

# Download the upstream listing into $1 and verify the result matches
# the checksums recorded in instant.db (catches missing, truncated and
# corrupt files alike).
sync_once() {
    snapshot="$1"
    if ! wget --mirror --level=1 --no-parent --no-host-directories \
        --no-directories --timestamping --no-verbose \
        --tries=3 --timeout=60 -e robots=off \
        --directory-prefix="$snapshot" \
        "$upstream_url" >>"$log_file" 2>&1; then
        return 1
    fi

    [ -s "$snapshot/instant.db" ] || return 1

    tar -xOf "$snapshot/instant.db" --wildcards '*/desc' |
        awk '/^%FILENAME%$/{getline; f=$0}
             /^%SHA256SUM%$/{getline; print $0 "  " f}' >"$checksums"

    [ "$(wc -l <"$checksums")" -ge 1 ] || return 1

    (cd "$snapshot" && sha256sum --check --quiet "$checksums") \
        >>"$log_file" 2>&1
}

mkdir -p "$snapshots_dir"

# Only one sync at a time (cron vs. manual run vs. playbook bootstrap).
exec 9>"$lock_file"
if ! flock -n 9; then
    log "another sync is still running, skipping"
    exit 0
fi

checksums="$data_dir/.db.sha256"
trap 'rm -f "$checksums"' EXIT

# Pick a unique snapshot name. Never reuse an existing one: the live
# snapshot `current` points at always exists, so this also makes it
# impossible to rm -rf the snapshot being served (two runs starting in
# the same second used to collide here).
snapshot=""
while [ -z "$snapshot" ]; do
    candidate="$snapshots_dir/$(date -u '+%Y%m%dT%H%M%S%NZ')"
    if [ ! -e "$candidate" ]; then
        snapshot="$candidate"
    else
        sleep 1
    fi
done

# Seed the new snapshot with the last served one so wget timestamping
# only re-downloads files that changed upstream.
rm -rf "$snapshot"
mkdir "$snapshot"
if [ -d "$current_link/." ]; then
    cp -a "$current_link/." "$snapshot/" >>"$log_file" 2>&1 || {
        rm -rf "$snapshot"
        fail "copying the previous snapshot failed"
    }
fi

log "syncing $upstream_url into $snapshot"

if ! sync_once "$snapshot"; then
    # Seeded sync failed - either upstream is broken or the local state
    # is. Retry once with a full re-download to rule out the latter.
    log "seeded sync failed, retrying with a full re-download"
    rm -rf "$snapshot"
    mkdir "$snapshot"
    sync_once "$snapshot" || {
        rm -rf "$snapshot"
        fail "sync failed even after a full re-download"
    }
fi

# Atomically switch what is being served (rename over the old symlink).
ln -sfn "$snapshot" "$data_dir/.current.tmp"
mv -Tf "$data_dir/.current.tmp" "$current_link"
log "now serving $snapshot"

# Retention: drop everything but the newest $keep_snapshots snapshots,
# never the one currently being served.
current_target="$(readlink -f "$current_link")"
for old in $(ls -1 "$snapshots_dir" | sort | head -n "-$keep_snapshots"); do
    [ "$snapshots_dir/$old" = "$current_target" ] && continue
    rm -rf "$snapshots_dir/$old"
    log "removed old snapshot $old"
done
