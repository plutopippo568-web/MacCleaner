# MacCleaner

App nativa SwiftUI per macOS (Apple silicon, compatibile con macOS 27 Golden Gate).

## Funzioni
- **Scansione intelligente**: spazio disco, totale da pulire e file grandi.
- **Pulizia sistema**: cache utente, log, DerivedData di Xcode, Cestino (eliminazione definitiva, con conferma).
- **File grandi**: file > 100 MB in Desktop, Documenti, Download, Film, Musica, Immagini (vanno nel Cestino).
- **Disinstallazione**: sposta nel Cestino l'app e i file residui in ~/Library, trovati tramite bundle ID.
- **Elementi di avvio**: elenca i LaunchAgents dell'utente (~/Library/LaunchAgents) e permette di spostarli nel Cestino; l'effetto si vede al prossimo login.
- **Spazio su disco**: naviga le cartelle con barre proporzionali ("Apri" per entrare, lente per mostrare nel Finder).
- **Manutenzione**: svuota cache DNS, reindicizza Spotlight, ricostruisci Launch Services, libera memoria (chiedono la password admin).

## Compilare (su un Mac)
    ./build_app.sh
oppure `swift build -c release`, oppure apri la cartella con Xcode (File > Open).

## Creare il DMG
    ./make_dmg.sh
Produce `MacCleaner.dmg` con l'app e il collegamento ad Applicazioni.
Senza un Mac: carica la cartella su un repository GitHub, vai in Actions > "Build DMG" > Run workflow e scarica l'artifact `MacCleaner-dmg`.

L'app è firmata ad-hoc, non notarizzata (serve un account Apple Developer): al primo avvio usa clic destro > Apri,
oppure Impostazioni di Sistema > Privacy e sicurezza > "Apri comunque".

## Permessi
Dai a MacCleaner **Accesso completo al disco** (Impostazioni di Sistema > Privacy e sicurezza) per leggere il Cestino e alcune cache.
L'app non usa la sandbox, altrimenti non potrebbe accedere a ~/Library.

## Sicurezza
Il codice rifiuta di toccare cartelle radice (~/Library, ~/Documents...) e tutto fuori da home e /Applications.
Controlla sempre l'elenco prima di confermare.

## Non incluso
Antimalware, monitor in tempo reale, elementi di login gestiti da "Impostazioni di Sistema > Generali > Elementi login" (solo i LaunchAgents utente sono coperti). Un vero rilevatore di malware richiede database di firme aggiornati e non è realistico da improvvisare.
