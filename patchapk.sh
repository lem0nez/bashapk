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

  SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
  DATA_DIR="$SCRIPT_DIR/data"

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

  for p in "$SCRIPT_DIR"/patches/*.sh; do
    # shellcheck --source-path=patches
    . "$p"
  done

  case $patch in
    rm-langs|rm-debug-info|rm-dummies|no-ads|no-analytics|no-billing)
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
      `'  rm-langs [resources...]      Remove languages that does not match\n'`
      `'                               the KEEP_LANG pattern (inside the\n'`
      `'                               patch script)\n'`
      `'  rm-debug-info [smali...]     Remove the debugging information in\n'`
      `'                               all files from the smali folder(s)\n'`
      `'  rm-dummies [resources...]    Remove unnecessary "dummies"\n'`
      `'                               generated by the ApkTool\n'`
      `'\n'`
      `'  no-ads [APK root...]          Disable ads\n'`
      `'  no-analytics [APK root...]    Disable analytic reports\n'`
      `'  no-billing [APK root...]      Disable the billing service\n' \
      "$0"
}

# Utilities

# Function returns the regex pattern of list.
# Takes a path of the list file (relative to the data directory).
get_list_pattern() {
  mapfile -t array < "$DATA_DIR/$1"
  IFS='|' pattern="(${array[*]})"
  echo "$pattern"
}

# Replace strings in the Smali code. Function takes the following parameters:
# 1. search pattern (make sure that pattern
#    doesn't match text outside the quotes);
# 2. replacement pattern;
# 3. boolean value: true for case sensative search and false otherwise;
# 4. paths.
replace_strings() {
  search_pattern="([^[:space:]\"]+\\s*)\"$1\"\\s*$"; shift
  replacement_pattern="\\1\"$1\""; shift
  is_case_sensative=$1; shift

  sed_search_pattern=${search_pattern//\//\\\/}
  sed_replacement_pattern=${replacement_pattern//\//\\\/}

  if [[ $is_case_sensative == true ]]; then
    grep_pattern_options='E'
    sed_flags='g'
  else
    grep_pattern_options='iE'
    sed_flags='Ig'
  fi

  # IFS= prevents trimming of leading whitespaces.
  while IFS= read -r f; do
    # Just print a matched line.
    if grep -snH"$grep_pattern_options" "$search_pattern" "$f"; then
      sed -ri "s/$sed_search_pattern/$sed_replacement_pattern/$sed_flags" "$f"
    fi
  done <<< "$(grep -rl"$grep_pattern_options" "$search_pattern" "$@")"
}

# Function takes:
# 1. Bash-compatible pattern of elements;
# 2. boolean value: true if you want to use the single
#    line matching (fast) and false if you don't know;
# 3. files paths.
del_xml_elements() {
  pattern="^[[:space:]]*<$1/?>"; shift
  use_signle_line_matching=$1; shift

  if [[ $use_signle_line_matching == true ]]; then
    sed_pattern=${pattern//\//\\\/}

    while IFS= read -r f; do
      if grep -snHE "$pattern" "$f"; then
        sed -ri "/$sed_pattern/d" "$f"
      fi
    done <<< "$(grep -lE "$pattern" "$@")"

    return
  fi

  while [[ -n $1 ]]; do
    file=$1

    unset line_number skip_line element_scope file_changed
    # Empty the temporary file.
    : > "$TMP_FILE"

    while IFS= read -r l; do
      line_number=$((line_number + 1))

      if [[ "$l" =~ $pattern ]]; then
        if [[ "$l" =~ (/>[[:space:]]*$) ]]; then
          # Skip only this line, as element has no child element(s).
          skip_line=
        else
          # Get the element name.
          element_scope=`
              `$(sed -r 's/^\s*<([^[:space:]]+)(\s+|>).*$/\1/' <<< "$l")
        fi
      fi

      # If the element has child element(s)...
      if [[ -n ${element_scope+SET} ]]; then
        # If it's a closing tag of the element...
        if [[ "$l" =~ (</$element_scope>[[:space:]]*$) ]]; then
          unset element_scope
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

    shift
  done
}

main "$@"
