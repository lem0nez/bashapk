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
  if [[ -z $2 ]]; then
    echo -e \
        'Specify at least two directories from the highest to lowest\n'`
        `'priority. Notice, that directories should contain only files.'
    exit 0
  fi

  # To avoid splitting of paths that contain whitespace characters.
  IFS=$'\0'

  while [[ -n $1 ]]; do
    for f in "${files[@]}"; do
      if [[ -f $1/$f ]]; then
        rm -v "$1/$f"
      fi
    done

    if [[ ! -d $1 ]]; then
      printf >&2 'Directory "%s" does not exist! Skipping...\n' "$1"
    else
      if [[ -z $(ls -A "$1") ]]; then
        # A directory is empty.
        rmdir -v "$1"
      else
        for f in "$1"/*; do
          if [[ ! "$IFS${files[*]}$IFS" =~ $IFS${f##*/}$IFS ]]; then
            # Add a file name that is not in the "files" array.
            files+=("${f##*/}")
          fi
        done
      fi
    fi

    shift
  done

  exit 0
}

main "$@"
