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

rm_debug_info() {
  pattern='^\s*(\.local\s+.+|\.line\s+[[:digit:]]+|\.prologue|'`
      `'\.end\s+local\s+.+|\.restart\s+local\s+.+|\.source\s+.+)\s*$'

  # grep faster than pure Bash patterns and mush faster than find.
  if grep -rlE "$pattern" "$1" | xargs -r sed -ri "/$pattern/d"; then
    printf '%s: done\n' "$1"
  else
    printf '%s: no changes\n' "$1"
  fi
}
