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

rm_dummies() {
  pattern='\s+name="APKTOOL_DUMMY_[^"]+"'

  while read -r f; do
    if [[ -n $f ]]; then
      grep -nHE "$pattern" "$f"
      sed -ri "/$pattern/d" "$f"
    fi
  done <<< "$(grep -lE "$pattern" "$1"/values/*.xml)"
}
