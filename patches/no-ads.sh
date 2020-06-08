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

no_ads() {
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

  rules_pattern=$(get_list_pattern no-ads/rules.list)
  methods_pattern="^(\\s*)invoke-.+$rules_pattern.*"`
      `"$(get_list_pattern no-ads/methods.list)\\(.*\\)(V|Z)\\s*$"
  sed_methods_pattern=${methods_pattern//\//\\\/}
  smali_dirs=("$1"/smali*)

  if (( ${#smali_dirs[@]} != 0 )); then
    replace_strings "[^\"]*${rules_pattern}[^\"]*" no-ads false \
        "${smali_dirs[@]}"

    while IFS= read -r f; do
      if grep -snHiE "$methods_pattern" "$f"; then
        sed -ri "s/$sed_methods_pattern/"`
            `"\\1invoke-static {}, LNoAds;->hook()\\4/Ig" "$f"
        hooked=
      fi
    done <<< "$(grep -rilE "$methods_pattern" "${smali_dirs[@]}")"
  fi

  layouts=("$1"/res/layout*/*.xml)

  if (( ${#layouts[@]} != 0 )); then
    for x in "${!xml_patterns[@]}"; do
      sed_search_pattern=${x//\//\\\/}
      sed_replacement_pattern=${xml_patterns[$x]//\//\\\/}

      while IFS= read -r f; do
        if grep -snHiE "$x" "$f"; then
          sed -ri "s/$sed_search_pattern/$sed_replacement_pattern/Ig" "$f"
        fi
      done <<< "$(grep -liE "$x" "${layouts[@]}")"
    done
  fi

  if [[ -n ${hooked+SET} ]]; then
    # Add class that contains hooks.
    cp -v "$DATA_DIR/no-ads/NoAds.smali" "$1/smali"
  fi
}
