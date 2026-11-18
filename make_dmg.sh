#!/bin/bash
# Crea MacCleaner.dmg (compila l'app e la impacchetta). Richiede un Mac con Xcode o Command Line Tools.
set -e
bash build_app.sh
STAGE=dmg_stage
rm -rf "$STAGE" MacCleaner.dmg
mkdir "$STAGE"
cp -R MacCleaner.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "MacCleaner" -srcfolder "$STAGE" -ov -format UDZO MacCleaner.dmg
rm -rf "$STAGE"
echo "Fatto: MacCleaner.dmg"
