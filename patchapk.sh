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
  unset TRASH_DIR
  DATA_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/data"

  if [[ ! -d $DATA_DIR ]]; then
    echo >&2 'Could not find data directory!'
    exit 1
  elif [[ -z $1 ]]; then
    print_help
    exit 0
  fi

  while [[ -n $1 && -z $patch ]]; do
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
        patch=$1 ;;
    esac
    shift
  done

  if [[ -z $patch ]]; then
    echo >&2 'Specify a patch!'
    exit 1
  fi

  case $patch in
    rm-debug-info)
      provide_dirs= ;;
    rm-ads)
      provide_dirs= ;;
    rm-analytics)
      provide_dirs= ;;
    *)
      printf >&2 'Unrecognized patch: %s\n' "$patch"
      exit 1 ;;
  esac

  if [[ -n ${provide_dirs+SET} ]]; then
    if [[ -z $1 ]]; then
      echo >&2 'Specify at least one directory!'
      exit 1
    fi

    while [[ -n $1 ]]; do
      if [[ ! -d $1 ]]; then
        printf >&2 'Directory "%s" does not exist! Skipping...\n' "$1"
      else
        "${patch//-/_}" "$1"
      fi
      shift
    done
  fi

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
      `'  rm-debug-info [smali...]      Remove the debugging information in\n'`
      `'                                all files from the smali folder(s)\n'`
      `'  rm-ads [APK root...]          Remove ads\n'`
      `'  rm-analytics [APK root...]    Disable analytic reports\n' \
      "$0"
}

# Patches

rm_debug_info() {
  pattern='^\s*(\.local\s+.+|\.line\s+[[:digit:]]+|\.prologue|'`
      `'\.end\s+local\s+.+|\.restart\s+local\s+.+|\.source\s+.+)\s*$'

  # grep mush faster than find.
  if grep -rlE "$pattern" "$1" | xargs sed -ri "/$pattern/d" 2>/dev/null; then
    printf '%s: done\n' "$1"
  else
    printf '%s: no changes\n' "$1"
  fi
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
  rules_pattern=$(get_list_pattern rm-ads/rules.list)
  # The number signs should be escaped!
  methods_pattern=`
      `"invoke-.*$(get_list_pattern rm-ads/methods.list)\\(.*\\)(V|Z)"

  replace_strings "[^\"]*${rules_pattern}[^\"]*" no-ads false "$1/smali"*

  while read -r f; do
    if [[ -z $f ]]; then
      continue
    fi

    unset line_number file_changed
    # Empty the temporary file.
    : > "$TMP_FILE"

    # IFS= prevents trimming of leading whitespaces.
    while IFS= read -r l; do
      line_number=$((line_number + 1))
      # ${l,,} converts line to lowercase.
      if [[ "${l,,}" =~ $rules_pattern && "$l" =~ $methods_pattern ]]; then
        echo "$f:$line_number:$l"
        echo "$l" | sed -r \
            "s#$methods_pattern#invoke-static {}, LNoAds;->hook()\\3#" >> \
            "$TMP_FILE"

        hooked=
        file_changed=
      else
        echo "$l" >> "$TMP_FILE"
      fi
    done < "$f"

    if [[ -n ${file_changed+SET} ]]; then
      cat "$TMP_FILE" > "$f"
    fi
  done <<< "$(grep -rlE "$methods_pattern" "$1/smali"*)"

  for x in "${!xml_patterns[@]}"; do
    while read -r f; do
      if [[ -n $f ]]; then
        grep -nHiE "$x" "$f"
        sed -ri "s#$x#${xml_patterns[$x]}#Ig" "$f"
      fi
    done <<< "$(grep -liE "$x" "$1/res/layout"*/*.xml)"
  done

  if [[ -n ${hooked+SET} ]]; then
    # Add class that contains hooks.
    cp -v "$DATA_DIR/rm-ads/NoAds.smali" "$1/smali"
  fi
}

rm_analytics() {
  replace_strings "[^\"]*$(get_list_pattern rm-analytics/links.list)[^\"]*" \
      no-analytics true "$1/smali"*
  remove_manifest_components \
      'com\.yandex\.metrica\.[^"]+' "$1/AndroidManifest.xml"
  # Yes, that's all!
}

# Utilities

# Function returns the regex pattern of list.
# Takes a path of the list file (relative to the data directory).
get_list_pattern() {
  mapfile -t array < "$DATA_DIR/$1"
  IFS='|' pattern="(${array[*]})"
  echo "$pattern"
}

# Replace strings in the smali code. Function takes the following parameters:
# 1. search pattern (make sure that pattern
#    doesn't match text outside the quotes);
# 2. replacement pattern;
# 3. boolean value: true for case sensative search and false otherwise;
# 4. paths.
#
# Notice: you should escape the number signs ('#')
# in patterns if you want to use them.
replace_strings() {
  search_pattern="([^[:space:]\"]+\s*)\"$1\"\s*$"; shift
  replacement_pattern="\\1\"$1\""; shift
  is_case_sensetive=$1; shift

  if [[ $is_case_sensetive == true ]]; then
    grep_pattern_options='E'
    sed_flags='g'
  else
    grep_pattern_options='iE'
    sed_flags='Ig'
  fi

  while read -r f; do
    if [[ -n $f ]]; then
      # Just print a matched line.
      grep -nH"$grep_pattern_options" "$search_pattern" "$f"
      sed -ri "s#$search_pattern#$replacement_pattern#$sed_flags" "$f"
    fi
  done <<< "$(grep -rl"$grep_pattern_options" "$search_pattern" "$@")"
}

# Remove the matched components from the manifest file. Parameters:
# 1. component name pattern (make sure that pattern
#    doesn't match text outside the quotes);
# 2. file path.
remove_manifest_components() {
  pattern="^[[:space:]]*<(activity|provider|receiver|service)"`
      `"[[:space:]].*android:name=\"$1\""
  file=$2

  unset line_number skip_line component_scope file_changed
  : > "$TMP_FILE"

  while IFS= read -r l; do
    line_number=$((line_number + 1))

    if [[ "$l" =~ $pattern ]]; then
      if [[ "$l" =~ (/>[[:space:]]*$) ]]; then
        # Skip only this line, as component has no child element(s).
        skip_line=
      else
        # Get the component type.
        component_scope=$(sed -r 's/^\s*<([a-z]+)\s+.+$/\1/' <<< "$l")
      fi
    fi

    # If component has child element(s)...
    if [[ -n ${component_scope+SET} ]]; then
      # If it's a closing tag of component...
      if [[ "$l" =~ (^[[:space:]]*</$component_scope>[[:space:]]*$) ]]; then
        unset component_scope
      fi
      skip_line=
    fi

    if [[ -n ${skip_line+SET} ]]; then
      unset skip_line
      echo "$file:$line_number:$l"
      file_changed=
    else
      echo "$l" >> "$TMP_FILE"
    fi
  done < "$file"

  if [[ -n ${file_changed+SET} ]]; then
    cat "$TMP_FILE" > "$file"
  fi
}

main "$@"
