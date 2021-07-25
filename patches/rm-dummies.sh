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

rm_dummies() {
  if [[ -n ${USE_XMLSTARLET+SET} ]]; then
    # "Dummies" generate only in the "values" folder.
    xmlstarlet_del '/resources/*[starts-with(@name, "APKTOOL_DUMMY_")]' \
        "$1"/values/*.xml
  else
    del_xml_elements '[^>]+[[:space:]]+name="APKTOOL_DUMMY_[^"]+"[^>]*' \
        true "$1"/values/*.xml
  fi
}
