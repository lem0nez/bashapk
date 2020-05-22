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

main() {
  unset TRASH_DIR PATCH

  if [[ -z $1 ]]; then
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
      `'  rm-debug-info [smali...]    Remove the debug information in\n'`
      `'                              all files from the smali folder(s)\n' \
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

main "$@"
