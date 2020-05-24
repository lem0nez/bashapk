#!/usr/bin/env bash

# Copyright © 2020 Nikita Dudko. All rights reserved.
# Contacts: <nikita.dudko.95@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -eo pipefail
shopt -s globstar nullglob

TMP_FILE=$(mktemp -t tmp.patchapk-XXXXXX)
cleanup() {
  rm -f "$TMP_FILE"
}
trap cleanup EXIT

main() {
  unset TRASH_DIR PATCH
  DATA_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/data"

  if [[ ! -d $DATA_DIR ]]; then
    echo >&2 'Could not find data directory!'
    exit 1
  elif [[ -z $1 ]]; then
    print_help
    exit 0
  fi

  while [[ -n $1 && -z $PATCH ]]; do
    case $1 in
      -h|--help)
        print_help
        exit 0 ;;
      -t|--trash)
        shift
        if [[ -z $1 ]]; then
          echo >&2 'Specify a directory for trash!'
          exit 1
        elif [[ ! -d $1 ]]; then
          printf >&2 'Directory "%s" does not exist!\n' "$1"
          exit 1
        fi
        TRASH_DIR=$1 ;;
      -*)
        printf >&2 'Unrecognized option: %s\n' "$1"
        exit 1 ;;
      *)
        PATCH=$1 ;;
    esac
    shift
  done

  if [[ -z $PATCH ]]; then
    echo >&2 'Specify a patch!'
    exit 1
  fi

  case $PATCH in
    rm-debug-info)
      if [[ -z $1 ]]; then
        echo >&2 'Specify at least one smali folder!'
        exit 1
      fi
      rm_debug_info "$@" ;;
    rm-ads)
      if [[ -z $1 ]]; then
        echo >&2 'Specify at least one root folder of the decompiled APK file!'
        exit 1
      fi
      rm_ads "$@" ;;
    *)
      printf >&2 'Unrecognized patch: %s\n' "$PATCH"
      exit 1 ;;
  esac

  exit 0
}

print_help() {
  printf 'Usage: %s [options...] [patch] ...\n'`
      `'\n'`
      `'Options:\n'`
      `'  -h, --help           Print the help message\n'`
      `'  -t, --trash [dir]    Set a directory for trash\n'`
      `'\n'`
      `'Patches:\n'`
      `'  rm-debug-info [smali...]    Remove the debugging information in\n'`
      `'                              all files from the smali folder(s)\n'`
      `'  rm-ads [APK root...]        Remove ads\n' \
      "$0"
}

rm_debug_info() {
  pattern='^\s*(\.local\s+.+|\.line\s+[[:digit:]]+|\.prologue|'`
      `'\.end\s+local\s+.+|\.restart\s+local\s+.+|\.source\s+.+)\s*$'

  while [[ -n $1 ]]; do
    if [[ -d $1 ]]; then
      # grep mush faster than find.
      if grep -rlE "$pattern" "$1" |
          xargs sed -ri "/$pattern/d" 2>/dev/null; then
        printf '%s: done\n' "$1"
      else
        printf '%s: no changes\n' "$1"
      fi
    else
      printf >&2 'Directory "%s" does not exist! Skipping...\n' "$1"
    fi
    shift
  done
}

rm_ads() {
  declare -A xml_patterns=(
    ['<([^>]+)(android:id="@id/(ads?|banner|adview)_?layout")([^>]+)'`
        `'android:layout_width="[^"]+"([^>]+)android:layout_height="[^"]+"']=`
        `'<\1\2\4android:layout_width="0.0dip"\5android:layout_height="0.0dip"'

    ['<com\.google\.android\.gms\.ads\.AdView([^>]+)'`
        `'android:layout_width="[^"]+"([^>]+)android:layout_height="[^"]+"']=`
        `'<com.google.android.gms.ads.AdView\1'`
        `'android:layout_width="0.0dip"\2android:layout_height="0.0dip"'

    ['ca-app-pub']='no-ads'
  )

  # Rules list should contains only lowercase rows!
  mapfile -t rules < "$DATA_DIR/rm-ads/rules.list"
  mapfile -t methods < "$DATA_DIR/rm-ads/methods.list"

  IFS='|' rules_pattern="(${rules[*]})"
  strings_pattern="([^[:space:]\"]+\s*)\"[^\"]*${rules_pattern}[^\"]*\""
  IFS='|' methods_pattern="invoke-.*(${methods[*]})\\(.*\\)(V|Z)"

  while read -r f; do
    if [[ -n $f ]]; then
      # Just print a matched line.
      grep -HiE "$strings_pattern" "$f"
      sed -ri "s#$strings_pattern#\\1\"no-ads\"#Ig" "$f"
    fi
  done <<< "$(grep -rliE "$strings_pattern" "$1/smali"*)"

  while read -r f; do
    if [[ -z $f ]]; then
      continue
    fi

    # Empty the temporary file.
    : > "$TMP_FILE"
    # IFS= prevents trimming of leading whitespaces.
    while IFS= read -r l; do
      # ${l,,} converts line to lowercase.
      if [[ "${l,,}" =~ $rules_pattern && "$l" =~ $methods_pattern ]]; then
        echo "$f:$l"
        echo "$l" | sed -r \
            "s#$methods_pattern#invoke-static {}, LNoAds;->hook()\\3#" >> \
            "$TMP_FILE"
        hooked=
      else
        echo "$l" >> "$TMP_FILE"
      fi
    done < "$f"
    cat "$TMP_FILE" > "$f"
  done <<< "$(grep -rlE "$methods_pattern" "$1/smali"*)"

  for x in "${!xml_patterns[@]}"; do
    while read -r f; do
      if [[ -n $f ]]; then
        grep -HiE "$x" "$f"
        sed -ri "s#$x#${xml_patterns[$x]}#Ig" "$f"
      fi
    done <<< "$(grep -liE "$x" "$1/res/layout"*/*.xml)"
  done

  if [[ -n ${hooked+SET} ]]; then
    # Add class that contains hooks.
    cp -v "$DATA_DIR/rm-ads/NoAds.smali" "$1/smali"
  fi
}

main "$@"
