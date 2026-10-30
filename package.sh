#!/bin/sh
set -e
cd "$(dirname "$0")"

INCLUDE="control.lua data.lua data-updates.lua data-final-fixes.lua info.json thumbnail.png CHANGELOG.txt LICENSE graphics locale migrations prototypes scripts"

package() {
  name=$(sed -n 's/.*"name": *"\([^"]*\)".*/\1/p' info.json)
  version=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' info.json)
  rm -rf "$name"
  mkdir "$name"
  cp -R $INCLUDE "$name"
  rm -f "${name}_${version}.zip"
  zip -rq "${name}_${version}.zip" "$name"
  rm -rf "$name"
}

package
mv info.json info-2.0.json
mv info-2.1.json info.json
trap 'mv info.json info-2.1.json; mv info-2.0.json info.json' EXIT
package