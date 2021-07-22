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
shopt -s globstar nullglob

# To avoid splitting of paths.
IFS=$'\n'
declare PATH_LIST_FILE
# A directory that contains XML files with paths to resources.
declare RES_PATHS_DIR

main() {
  if [[ -z $1 ]]; then
    print_help
    exit 0
  fi

  local arsc_dir
  while [[ -n $1 ]]; do
    case $1 in
      -l|--list)
        shift
        if [[ -z $1 ]]; then
          echo >&2 'Specify a file to append path list!'
          exit 1
        elif [[ -e $1 ]]; then
          if [[ -d $1 ]]; then
            echo >&2 "\"$1\" exists, but it's directory!"
            exit 1
          elif [[ ! -w $1 ]]; then
            echo >&2 "File \"$1\" isn't writable!"
            exit 1
          fi
        fi
        PATH_LIST_FILE=$1 ;;
      -a|--arsc)
        shift
        if [[ -z $1 ]]; then
          echo >&2 'Specify a directory of the decompiled resources.arsc file!'
          exit 1
        elif [[ ! -e $1 ]]; then
          echo >&2 "Directory \"$1\" doesn't exist!"
          exit 1
        elif [[ ! -d $1 ]]; then
          echo >&2 "\"$1\" isn't a directory!"
          exit 1
        fi
        # Trim all trailing slashes.
        arsc_dir=${1%${1##*[!/]}} ;;
      -h|--help)
        print_help
        exit 0 ;;
      -*)
        echo >&2 "Unrecognized option: $1"
        exit 1 ;;
      *)
        break ;;
    esac
    shift
  done
  readonly PATH_LIST_FILE

  if [[ -z $2 ]]; then
    echo -e \
        'Specify at least two directories from highest to lowest\n'`
        `'priority. Notice, that directories must contain only files.'
    exit 1
  fi

  # Contains all provided directories without trailing slashes.
  local -a dirs
  for d in "$@"; do
    dirs+=("${d%${d##*[!/]}}")
  done

  if [[ -n $arsc_dir ]]; then
    local dir_name=${dirs[0]}
    dir_name=${dir_name##*/}
    # Exclude all qualifiers from the subdirectory name.
    RES_PATHS_DIR="$arsc_dir/${dir_name%%-*}"

    if [[ ! -d $RES_PATHS_DIR ]]; then
      echo >&2 "Directory with resource paths \"$RES_PATHS_DIR\" doesn't exist!"
      exit 1
    fi
  fi
  readonly RES_PATHS_DIR

  local real_path
  # Used to detect duplicates in provided directories.
  local -a real_paths

  for d in "${dirs[@]}"; do
    if [[ ! -e $d ]]; then
      echo >&2 "Directory \"$d\" doesn't exist!"
      exit 1
    elif [[ ! -d $d ]]; then
      echo >&2 "\"$d\" isn't a directory!"
      exit 1
    fi

    real_path=$(readlink -ne "$d")
    # Path already provided?
    if [[ "$IFS${real_paths[*]}$IFS" =~ $IFS$real_path$IFS ]]; then
      echo >&2 "\"$d\" is duplicate!"
      exit 1
    else
      real_paths+=("$real_path")
    fi

    if [[ -n $RES_PATHS_DIR ]]; then
      dir_name=${d##*/}
      if [[ $arsc_dir/${dir_name%%-*} != "$RES_PATHS_DIR" ]]; then
        echo >&2 'All resource directories must be of the same type!'
        exit 1
      fi
    fi
  done

  if [[ -n $RES_PATHS_DIR ]]; then
    echo "Resource paths directory: $RES_PATHS_DIR"
  fi

  rmdupes "${dirs[@]}"
  exit 0
}

rmdupes() {
  # Current directory being processed.
  local dir
  local filename
  # Files in the processed directory.
  local -a dir_files
  # All collected filenames.
  local -a files
  # Paths of removed files from the processed directory.
  local -a dir_rm_paths
  local -i rm_dirs_count=0

  if [[ -n $RES_PATHS_DIR ]]; then
    # Files that may contain paths to resources.
    local -ra res_paths_files=("$RES_PATHS_DIR/${RES_PATHS_DIR##*/}"*.xml)
    # Pattern of XML entries with paths that will be deleted.
    local paths_xml_pattern

    # Number of matched path entries of removed files.
    local -i matched_path_entries
    # If number of removed files and deleted path entries
    # don't match, then a warning will be displayed.
    local warn_about_path_entries_count
  fi

  while [[ -n $1 ]]; do
    dir=$1
    dir_rm_paths=()

    echo -en "\n$dir: "

    for f in "${files[@]}"; do
      # A file already exists in directory with highest priority?
      if [[ -f $dir/$f ]]; then
        rm "$dir/$f"
        dir_rm_paths+=("$dir/$f")
      fi
    done

    echo -n "${#dir_rm_paths[@]} file"
    if (( ${#dir_rm_paths[@]} != 1 )); then
      echo -n 's'
    fi
    echo

    if [[ -n $RES_PATHS_DIR ]] && (( ${#dir_rm_paths[@]} != 0 )); then
      paths_xml_pattern="^[[:space:]]+<[[:alnum:]._-]+[[:space:]]+"`
                       `"name=\"[^\"]+\">res\\/${dir##*/}\\/("
      for f in "${dir_rm_paths[@]}"; do
        paths_xml_pattern="$paths_xml_pattern${f##*/}|"
      done
      paths_xml_pattern="${paths_xml_pattern%|})<\\/[[:alnum:]._-]+>$"

      matched_path_entries=`
          `$(grep -hxoE "$paths_xml_pattern" "${res_paths_files[@]}" | wc -l)
      echo "Matched path entries: $matched_path_entries"
      sed -ri "/$paths_xml_pattern/d" "${res_paths_files[@]}"

      if (( matched_path_entries != ${#dir_rm_paths[@]} )); then
        warn_about_path_entries_count=1
      fi
    fi

    if [[ -z $(ls -A "$dir") ]]; then
      # A directory is empty.
      rmdir "$dir"
      echo 'Directory removed.'
      (( ++rm_dirs_count ))

      if [[ -n $PATH_LIST_FILE ]]; then
        echo "$dir/*" >> "$PATH_LIST_FILE"
      fi
    else
      dir_files=("$dir"/* "$dir"/.[!.]*)
      for f in "${dir_files[@]}"; do
        filename=${f##*/}
        if [[ -d $f ]]; then
          echo "Directory \"$filename\" skipped"
        elif [[ ! "$IFS${files[*]}$IFS" =~ $IFS$filename$IFS ]]; then
          # Add a file name that is not in the "files" array.
          files+=("$filename")
        fi
      done

      if [[ -n $PATH_LIST_FILE ]] && (( ${#dir_rm_paths[@]} != 0 )); then
        echo "${dir_rm_paths[*]}" >> "$PATH_LIST_FILE"
      fi
    fi

    shift
  done

  local -r rm_dirs_msg="\nRemoved directories: $rm_dirs_count"

  if [[ -n $RES_PATHS_DIR ]]; then
    local -a empty_arsc_files
    mapfile -t empty_arsc_files < \
        <(grep -lzP '\n<resources>\n</resources>\n?$' "${res_paths_files[@]}")

    if (( ${#empty_arsc_files[@]} != 0 )); then
      echo -e "\nRemoving empty resources.arsc's files:"
      for f in "${empty_arsc_files[@]}"; do
        echo " - ${f##*/}"
        rm "$f"
      done
    fi

    echo -e "$rm_dirs_msg\n"`
           `"Removed resources.arsc's files: ${#empty_arsc_files[@]}"
    if [[ -n $warn_about_path_entries_count ]]; then
      echo -e "\nWarning: number of removed files "`
             `"and deleted path entries don't match"
    fi
  else
    echo -e "$rm_dirs_msg"
  fi
}

print_help() {
  printf 'Usage: %s [options...] <directories...>\n'`
        `'Options:\n'`
        `'  -l, --list <file>    Append path list of removed items to a file.\n'`
        `'  -a, --arsc <dir>     Set directory of the decompiled\n'`
        `'                       by MT Manager resources.arsc file;\n'`
        `'                       entries with corresponding paths\n'`
        `'                       will be removed from XML files.\n'`
        `'  -h, --help           Print this message and exit.\n' \
        "$0"
}

main "$@"
