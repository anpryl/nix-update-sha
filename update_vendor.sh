#!/usr/bin/env bash
# set -e

packageFile=${PACKAGE_FILE:-./package.nix}
buildAttr=${BUILD_ATTR}

l="$(mktemp)"
trap "rm ${l}" EXIT

echo "packageFile="$packageFile
vendorHash=$(grep vendorHash "$packageFile" | cut -f2 -d'"')
echo "vendorHash="$vendorHash
sed -i "s|${vendorHash}|0000000000000000000000000000000000000000000000000000|" "$packageFile"
nix build ".#${buildAttr}" --no-link &>"${l}" || true
cat ${l}
newvendorHash="$(cat "${l}" | grep 'got:' | cut -d':' -f2 | tr -d ' ' || true)"
echo $newvendorHash
[ ! -z "$newvendorHash" ] || exit 0
if [[ "${newvendorHash}" == "sha256" ]]; then newvendorHash="$(cat "${l}" | grep 'got:' | cut -d':' -f3 | tr -d ' ' || true)"; fi
newvendorHash="$(nix hash to-base32 --type sha256 "${newvendorHash}")"
sed -i "s|0000000000000000000000000000000000000000000000000000|${newvendorHash}|" "$packageFile"

git diff-index --quiet HEAD "${pkg}" ||
	git commit "$packageFile" -m "[CI SKIP] Update vendorHash in ${packageFile}: ${vendorHash} => ${newvendorHash}"
echo "done updating ${packageFile} (${vendorHash} => ${newvendorHash})"
if [ "$PUSH" = true ]; then
	git push origin $(git branch --show-current $BRANCH_NAME) || echo "Failed to push to origin. Not on the top of the stream?"
fi

exit 0
