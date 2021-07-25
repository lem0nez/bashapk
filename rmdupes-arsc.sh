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

# Number of spaces to indent.
# Used by formatter, which is called if a XML file was modified.
readonly XML_INDENT_SIZE=4
# Maximum number of value variations for an attribute in one XPath.
# If exceeded, XPath will be split to avoid the “Argument list too long” error.
readonly MAX_XPATH_ATTR_VALS=1024

main() {
  if ! command -v xmlstarlet &>/dev/null; then
    echo >&2 'xmlstarlet not found! '`
            `'Please install it or update the PATH variable'
    exit 1
  elif [[ -z $2 ]]; then
    echo -e 'Specify at least two XML files, from highest to lowest priority'
    exit 0
  fi

  check_files "$@"
  rmdupes "$@"
  exit 0
}

rmdupes() {
  # Current XML file being processed.
  local file
  # Number of resources in the processed file.
  local -i res_count
  local -i del_res_count
  # Resource names in the processed file.
  local -a names

  # Resource names of the processed part.
  local -a part_names
  local -i name_idx
  # Last name index of the processed part.
  local -i part_last_idx

  # Joined resource names for XPath.
  local attr_vals
  # XPaths of resources to delete.
  local -a xpaths

  echo 'Processing resources:'
  while [[ -n $1 ]]; do
    file=$1
    echo -n " - $file"
    res_count=$(xmlstarlet sel -t -v 'count(/resources/*/@name)' "$file")

    for p in "${xpaths[@]}"; do
      xmlstarlet ed -P -L -d "$p" "$file"
    done
    if (( ${#xpaths[@]} != 0 )); then
      # Delete remaining whitespaces after editing.
      # shellcheck disable=SC2005
      echo "$(xmlstarlet fo -s "$XML_INDENT_SIZE" "$file")" > "$file"
    fi

    mapfile -d $'\n' -t names < \
        <(xmlstarlet sel -t -v '/resources/*/@name' "$file")

    del_res_count=$((res_count - ${#names[@]}))
    echo -n " ($del_res_count / $res_count deleted)"

    if (( ${#names[@]} != 0 )); then
      name_idx=0
      part_last_idx=0

      while (( name_idx != ${#names[@]} )); do
        if (( ${#names[@]} - name_idx > MAX_XPATH_ATTR_VALS )); then
          (( part_last_idx += MAX_XPATH_ATTR_VALS ))
        else
          part_last_idx=${#names[@]}
        fi

        part_names=()
        while (( name_idx != part_last_idx )); do
          part_names+=("${names[$name_idx]}")
          (( ++name_idx ))
        done

        attr_vals=$(printf '%s' "${part_names[0]}" \
                                "${part_names[@]/#/\"or@name=\"}")
        xpaths+=("/resources/*[@name=\"$attr_vals\"]")
      done
    elif ! xmlstarlet sel -t -v 'name(/*/*[1])' "$file"; then
      rm "$file"
      echo -n ': file removed'
    fi

    echo
    shift
  done
}

check_files() {
  # Avoid splitting of paths.
  IFS=$'\n'

  local real_path
  # Used to detect duplicates.
  local -a real_paths

  local filename=${1##*/}
  filename=${filename%.*}
  # Qualifiers excluded form a file name.
  local -r res_type=${filename%%-*}

  for f in "$@"; do
    if [[ ! -e $f ]]; then
      echo >&2 "File \"$f\" doesn't exist!"
      exit 1
    elif [[ -d $f || ${f##*.} != 'xml' ]]; then
      echo >&2 "\"$f\" isn't a XML file!"
      exit 1
    elif [[ ! -w $f ]]; then
      echo >&2 "File \"$f\" isn't writable!"
      exit 1
    fi

    real_path=$(readlink -ne "$f")
    # Path already provided?
    if [[ "$IFS${real_paths[*]}$IFS" =~ $IFS$real_path$IFS ]]; then
      echo >&2 "\"$f\" is duplicate!"
      exit 1
    else
      real_paths+=("$real_path")
    fi

    filename=${f##*/}
    filename=${filename%.*}
    if [[ ${filename%%-*} != "$res_type" ]]; then
      echo >&2 'All resources must be of the same type!'
      exit 1
    fi
  done

  unset IFS
}

main "$@"
