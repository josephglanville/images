#!/bin/bash

# Copyright 2024 Google Inc. All rights reserved.

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

if [ $(uname) == "Darwin" ]; then
    if [ ! -d "/opt/homebrew/opt/coreutils" ]; then
        echo "ERROR: coreutils is not installed"
        exit 1
    fi
    export PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"
    if [ ! -d "/opt/homebrew/opt/gnu-sed" ]; then
        echo "ERROR: gnu-sed is not installed"
        exit 1
    fi
    export PATH="/opt/homebrew/opt/gnu-sed/libexec/gnubin:$PATH"
fi

function find_latest_snapshot() {
    local type="$1"
    # If it's the first of the month, look at the last month, otherwise this -1 day has no effect since searches
    # occur at the "month" level. This is an intentional buffer added to get the snapshots fully hydrated. We
    # intentionally don't include complicated logic for the case where it's after the 1st and no snapshots are
    # availalbe for the month (it's extremely unlikely for our updater to run into this situation unless the
    # snapshot serving infrastructure is acting up).
    local current="$(date -d '-1 day' +%Y-%m-%d)"
    local tmp=$(mktemp)
    local q=$(date -d "$current" +"year=%Y&month=%m")
    if curl -fs "https://snapshot.debian.org/archive/debian/?$q" | grep -ohE "([0-9]+T[0-9]+Z)" > $tmp; then
      # same logic as above, find the newest snapshot that isn't "today"
      today=$(date +"%Y%m%dT")
      cat $tmp | grep -v $today | tail -n1
    fi
}

function cmd_update_snapshots() {
    echo "🧐 Looking for updates... "
    latest=$(find_latest_snapshot "debian")
    latest_security=$(find_latest_snapshot "debian-security")
    if [[ -z "$latest" || -z "$latest_security" ]]; then
        echo ""
        echo "could not find any snapshots for debian or debian-security"
        exit 1
    fi
    echo ""
    echo "🎯 Found snapshots"
    echo "   debian: $latest"
    echo "   security: $latest_security"
    echo ""

    # if tty ask for approval
    if [ -t 1 ]; then
        read -p "Do you want to continue? (y/n) " -n 1 -r
        sleep 0.5
        echo $'\n'
        if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
            echo "Aborting..."
            exit 0
        fi
    fi

    for mpath in "./"*.yaml; do
        current=$(grep -oE "debian/([0-9]+T[0-9]+Z)" $mpath | cut -d/ -f2 | head -n1)
        current_security=$(grep -oE "debian-security/([0-9]+T[0-9]+Z)" $mpath | cut -d/ -f2 | head -n1)

        if [[ "$current" == "$latest" && "$current_security" == "$latest_security" ]]; then
            echo "🎖️ $mpath is up to date."
            continue
        fi
        echo "🗞️ $mpath"
        if [[ "$current" != "$latest" ]]; then
            sed -i -E "s/(debian\/)([0-9]+T[0-9]+Z)/\1$latest/" "$mpath"
            echo "   debian: $current -> $latest"
        fi
        if [[ "$current_security" != "$latest_security" ]]; then
            sed -i -E "s/(debian-security\/)([0-9]+T[0-9]+Z)/\1$latest_security/" "$mpath"
            echo "   debian-security: $current_security -> $latest_security"
        fi
        echo ""
    done
    echo ""
    echo "👌 Done..."
}

function cmd_lock() {
    echo "🚧 Querying for repos (temporarily using hardcoded repos)"
    echo ""
    # temporarily hardcode right now (query doesn't work after bzl mod)
    local repos=$(cat <<EOL
bullseye
EOL
)
    #repos=$(bazel query "kind('deb_package_index', //external:*)" --output=label 2>/dev/null | cut -d: -f2)

    for repo in $repos; do
      for i in $(seq 10); do
        echo "🔑 Locking $repo (attempt ${i})"
        bazel run "@${repo}//:lock" && break || sleep 20;
        if [[ $i -eq 10 ]]; then
          echo ""
          echo "Failed to lock $repo after 10 attempts" >&2
          exit 1
        fi
      done
    done
}

cmd_update_snapshots
cmd_lock
