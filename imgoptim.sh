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

main() {
  unset NO_STATS NO_OPTIPNG NO_JPEGOPTIM FREED_BYTES

  if [[ -z $1 ]]; then
    print_help
    exit 0
  fi

  while [[ -n $1 ]]; do
    case $1 in
      -h|--help)
        print_help
        exit 0 ;;
      -n|--no-stats)
        NO_STATS= ;;
      -o|--no-optipng)
        NO_OPTIPNG= ;;
      -j|--no-jpegoptim)
        NO_JPEGOPTIM= ;;
      -*)
        printf >&2 'Unrecognized option: %s\n' "$1"
        exit 1 ;;
      *)
        break ;;
    esac

    shift
  done

  if [[ -z $1 ]]; then
    echo >&2 'Specify at least one directory or image!'
    exit 1
  fi

  while [[ -n $1 ]]; do
    if [[ ! -e $1 ]]; then
      printf >&2 '"%s" does not exist! Skipping...\n' "$1"
    elif [[ -f $1 && ! ${1,,} =~ (\.(png|jpe?g)$) ]]; then
      printf >&2 '"%s" has invalid extension! Skipping...\n' "$1"
    else
      optimize "$1"
    fi

    shift
  done

  if [[ -n ${FREED_BYTES+SET} ]]; then
    if (( FREED_BYTES > 10240 )); then
      printf 'Reduced %i KB\n' $((FREED_BYTES / 1024))
    else
      printf 'Reduced %i bytes\n' "$FREED_BYTES"
    fi
  fi

  exit 0
}

print_help() {
  printf 'Usage: %s [options...] <directories/images...>\n'`
      `'Options:\n'`
      `'  -h, --help            Print the help message\n'`
      `'  -n, --no-stats        Do not calculate freed space\n'`
      `'  -o, --no-optipng      Do not use optipng\n'`
      `'  -j, --no-jpegoptim    Do not use jpegoptim\n' \
      "$0"
}

optimize() {
  while IFS= read -r f; do
    if [[ -z $f ]]; then
      continue
    fi

    if [[ -z ${NO_STATS+SET} ]]; then
      size=$(get_size "$f")
    fi

    # If a file extension starts with 'p' or 'P'...
    if [[ ${f##*.} =~ ^(p|P) ]]; then
      if [[ -z ${NO_OPTIPNG+SET} ]]; then
        optipng -o7 -strip all "$f"
      fi
    elif [[ -z ${NO_JPEGOPTIM+SET} ]]; then
      jpegoptim -s --strip-com --strip-exif \
          --strip-iptc --strip-icc --strip-xmp "$f"
    fi

    if [[ -z ${NO_STATS+SET} ]]; then
      FREED_BYTES=$((FREED_BYTES - $(get_size "$f") + size))
    fi
  done <<< "$(find "$1" -type f -iregex '.*\.\(png\|jpg\|jpeg\)$')"
}

get_size() {
  du -b "$1" | cut -f1
}

main "$@"
