#!/bin/bash
set -euo pipefail

if [[ $# -ne 2 || ! $1 == *.app || ! -d $1/Contents ]]; then
    echo "Uso: $0 CAMINHO_DO_APP CAMINHO_DO_DMG" >&2
    exit 2
fi

app=$1
dmg=$2
if [[ -e $dmg ]]; then
    echo "O DMG já existe: $dmg" >&2
    exit 2
fi

codesign --verify --deep --strict "$app"
xcrun stapler validate "$app"

mkdir -p "$(dirname "$dmg")"
staging=$(mktemp -d /private/tmp/pokedock-dmg.XXXXXX)
trap 'rm -rf "$staging"' EXIT

/usr/bin/ditto "$app" "$staging/$(basename "$app")"
ln -s /Applications "$staging/Applications"
hdiutil create -volname PokeDock -srcfolder "$staging" -format UDZO "$dmg"
hdiutil verify "$dmg"
echo "DMG criado: $dmg"
echo "Próximo passo: assinar e notarizar o DMG antes de gerar o appcast."
