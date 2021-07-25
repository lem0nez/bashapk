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

no_analytics() {
  replace_strings "[^\"]*$(get_list_pattern no-analytics/links.list)[^\"]*" \
      no-analytics true "$1"/smali*

  if [[ -n ${USE_XMLSTARLET+SET} ]]; then
    xmlstarlet_del '/manifest/application/*[self::receiver or self::service]'`
                  `'[starts-with(@android:name, "com.yandex.metrica.")]' \
                  "$1/AndroidManifest.xml"
  else
    del_xml_elements '(receiver|service)[[:space:]]+[^>]*android:name='`
        `'"com\.yandex\.metrica\.[^"]+"[^>]*' false "$1/AndroidManifest.xml"
  fi
}
