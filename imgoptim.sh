#!/usr/bin/env bash

# Copyright © 2021 Nikita Dudko. All rights reserved.
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
  unset \
      PATH_LIST_FILE \
      NO_STATS NO_OPTIPNG NO_JPEGOPTIM NO_CWEBP \
      FREED_BYTES

  if [[ -z $1 ]]; then
    print_help
    exit 0
  fi

  while [[ -n $1 ]]; do
    case $1 in
      -s|--no-stats)
        NO_STATS= ;;
      -o|--no-optipng)
        NO_OPTIPNG= ;;
      -j|--no-jpegoptim)
        NO_JPEGOPTIM= ;;
      -c|--no-cwebp)
        NO_CWEBP= ;;
      -l|--list)
        shift
        if [[ -z $1 ]]; then
          echo >&2 'Specify a file to append path list!'
          exit 1
        elif [[ -e $1 ]]; then
          if [[ -d $1 ]]; then
            echo >&2 "\"$1\" is a directory!"
            exit 1
          elif [[ ! -w $1 ]]; then
            echo >&2 "File \"$1\" exists, but it's not writable!"
            exit 1
          fi
        fi
        PATH_LIST_FILE=$1 ;;
      -h|--help)
        print_help
        exit 0 ;;
      -*)
        printf >&2 'Unrecognized option: %s\n' "$1"
        exit 1 ;;
      *)
        break ;;
    esac
    shift
  done

  local -r install_msg='Please install it or update the PATH variable'
  if [[ -z ${NO_OPTIPNG+SET} ]] && ! command -v optipng &>/dev/null; then
    echo >&2 "optipng not found! $install_msg"
    exit 1
  elif [[ -z ${NO_JPEGOPTIM+SET} ]] && ! command -v jpegoptim &>/dev/null; then
    echo >&2 "jpegoptim not found! $install_msg"
    exit 1
  fi

  if [[ -z ${NO_CWEBP+SET} ]]; then
    if ! command -v cwebp &>/dev/null; then
      echo >&2 "cwebp not found! $install_msg"
      exit 1
    fi

    # Output result to temporary file as cwebp can't overwrite an existing file.
    declare -g TMP_WEBP
    readonly TMP_WEBP=$(mktemp -t 'imgoptim-XXXXXX.webp')
    trap 'rm -f -- "$TMP_WEBP"' EXIT
  fi

  if [[ -z $1 ]]; then
    echo >&2 'Specify at least one directory or image!'
    exit 1
  fi

  while [[ -n $1 ]]; do
    if [[ ! -e $1 ]]; then
      printf >&2 '"%s" does not exist! Skipping...\n' "$1"
    elif [[ -f $1 && ! ${1,,} =~ (\.(png|jpe?g|webp)$) ]]; then
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

optimize() {
  local file_ext
  local -i result_size

  while IFS= read -r f; do
    if [[ -z $f ]]; then
      continue
    fi

    if [[ -z ${NO_STATS+SET} ]]; then
      size=$(get_size "$f")
    fi
    if [[ -n $PATH_LIST_FILE ]]; then
      modification_time=$(stat -c %Y "$f")
    fi

    file_ext=${f##*.}
    file_ext=${file_ext,,}
    result_size=0

    if [[ ${file_ext::1} == 'p' ]]; then
      if [[ -z ${NO_OPTIPNG+SET} ]]; then
        optipng -o7 -strip all "$f"
      fi
    elif [[ ${file_ext::1} == 'j' ]]; then
      if [[ -z ${NO_JPEGOPTIM+SET} ]]; then
        jpegoptim -s --strip-com --strip-exif \
            --strip-iptc --strip-icc --strip-xmp "$f"
      fi
    elif [[ -z ${NO_CWEBP+SET} ]]; then
      cwebp -z 9 -alpha_filter 'best' -exact -mt -progress "$f" -o "$TMP_WEBP"

      result_size=$(get_size "$TMP_WEBP")
      if (( result_size < size )); then
        cp "$TMP_WEBP" "$f"
      else
        echo "File \"$f\" skipped"
        result_size=$size
      fi
    fi

    if [[ -n $PATH_LIST_FILE ]] &&
        (( $(stat -c %Y "$f") != modification_time )); then
      echo "$f" >> "$PATH_LIST_FILE"
    fi
    if [[ -z ${NO_STATS+SET} ]]; then
      if (( result_size == 0 )); then
        result_size=$(get_size "$f")
      fi
      FREED_BYTES=$((FREED_BYTES - result_size + size))
    fi
  done <<< "$(find "$1" -type f -iregex '.*\.\(png\|jpg\|jpeg\|webp\)$')"
}

get_size() {
  du -b "$1" | cut -f1
}

print_help() {
  printf 'Usage: %s [options...] <directories / images...>\n'`
        `'Options:\n'`
        `'  -s, --no-stats        Do not calculate freed space.\n'`
        `'  -o, --no-optipng      Do not use optipng.\n'`
        `'  -j, --no-jpegoptim    Do not use jpegoptim.\n'`
        `'  -c, --no-cwebp        Do not use cwebp.\n'`
        `'\n'`
        `'  -l, --list <file>     Append path list of\n'`
        `'                        modified images to a file.\n'`
        `'  -h, --help            Print the help message.\n' \
        "$0"
}

main "$@"
