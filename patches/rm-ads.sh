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

rm_ads() {
  declare -A xml_patterns=(
    ['<([^>]+)(android:id="@id/(ads?|banner|adview)_?layout")([^>]+)'`
        `'android:layout_width="[^"]+"([^>]+)android:layout_height="[^"]+"']=`
        `'<\1\2\4android:layout_width="0.0dip"\5android:layout_height="0.0dip"'

    ['<com\.google\.android\.gms\.ads\.AdView([^>]+)'`
        `'android:layout_width="[^"]+"([^>]+)android:layout_height="[^"]+"']=`
        `'<com.google.android.gms.ads.AdView\1'`
        `'android:layout_width="0.0dip"\2android:layout_height="0.0dip"'

    ['ca-app-pub']='no-ads'
  )

  # Rules list should contains only lowercase rows!
  rules_pattern=$(get_list_pattern rm-ads/rules.list)
  # The number signs should be escaped!
  methods_pattern=`
      `"invoke-.*$(get_list_pattern rm-ads/methods.list)\\(.*\\)(V|Z)"

  replace_strings "[^\"]*${rules_pattern}[^\"]*" no-ads false "$1/smali"*

  while read -r f; do
    if [[ -z $f ]]; then
      continue
    fi

    unset line_number file_changed
    # Empty the temporary file.
    : > "$TMP_FILE"

    # IFS= prevents trimming of leading whitespaces.
    while IFS= read -r l; do
      line_number=$((line_number + 1))
      # ${l,,} converts line to lowercase.
      if [[ "${l,,}" =~ $rules_pattern && "$l" =~ $methods_pattern ]]; then
        echo "$f:$line_number:$l"
        echo "$l" | sed -r \
            "s#$methods_pattern#invoke-static {}, LNoAds;->hook()\\3#" >> \
            "$TMP_FILE"

        hooked=
        file_changed=
      else
        echo "$l" >> "$TMP_FILE"
      fi
    done < "$f"

    if [[ -n ${file_changed+SET} ]]; then
      cat "$TMP_FILE" > "$f"
    fi
  done <<< "$(grep -rlE "$methods_pattern" "$1/smali"*)"

  for x in "${!xml_patterns[@]}"; do
    while read -r f; do
      if [[ -n $f ]]; then
        grep -nHiE "$x" "$f"
        sed -ri "s#$x#${xml_patterns[$x]}#Ig" "$f"
      fi
    done <<< "$(grep -liE "$x" "$1/res/layout"*/*.xml)"
  done

  if [[ -n ${hooked+SET} ]]; then
    # Add class that contains hooks.
    cp -v "$DATA_DIR/rm-ads/NoAds.smali" "$1/smali"
  fi
}
