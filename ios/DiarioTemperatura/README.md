# Diario Temperatura — app iOS e widget

Questa cartella contiene il client iOS nativo e il widget WidgetKit. È separata dalla PWA GitHub Pages e usa lo stesso progetto Supabase della nuova app cloud.

## Funzioni

- Accesso con le stesse credenziali email/password della PWA cloud.
- Lettura delle misurazioni tramite Supabase Auth e policy RLS.
- Cache condivisa tramite App Group tra app e widget.
- Widget piccolo, medio e grande: ultima temperatura, data/ora e tempo trascorso dall'ultima registrazione di Nurofen, Tachipirina e Antibiotico.
- Aggiornamento quando l'app torna in primo piano e richiesta di refresh in background tramite BGAppRefreshTask.

Il widget non effettua chiamate di rete autonome: legge la cache condivisa aggiornata dall'app. iOS decide se e quando eseguire il refresh in background e può ritardarlo; non è possibile garantire aggiornamenti continui o in tempo reale.

## Configurazione una tantum per la firma Apple

Gli identificativi nel progetto sono segnaposto iniziali:

- Bundle app: `it.diariotemperatura.app`
- Bundle widget: `it.diariotemperatura.app.widget`
- App Group: `group.it.diariotemperatura.shared`

Prima di installare su un dispositivo o distribuire con TestFlight, registrare un App ID univoco e l'App Group nel proprio Apple Developer account. Se si cambia l'App Group, aggiornare lo stesso valore in:
- `Sources/Shared/WidgetSnapshot.swift`
- `Sources/App/DiarioTemperatura.entitlements`
- `Sources/Widget/DiarioTemperaturaWidget.entitlements`

Aggiornare anche i bundle identifier in `project.yml` affinché siano univoci e coerenti con il Developer Team.

## Generare il progetto Xcode

Serve un Mac con Xcode e XcodeGen:

```bash
brew install xcodegen
cd ios/DiarioTemperatura
xcodegen generate
open DiarioTemperatura.xcodeproj
```

In Xcode:
1. Selezionare il target `DiarioTemperatura` e impostare il proprio Team in Signing & Capabilities.
2. Verificare che l'App Group sia abilitato su entrambi i target (app e widget).
3. Collegare un iPhone, selezionarlo come destinazione e avviare l'app.
4. Accedere con l'account già usato nella PWA cloud.
5. Aggiungere il widget dalla schermata Home: pressione prolungata → modifica → aggiungi widget → Diario temperatura.

## TestFlight

La distribuzione TestFlight richiede l'iscrizione Apple Developer Program, gli identificativi registrati e la firma dell'app. Non sono inclusi certificati, password Apple o chiavi private nel repository.

## Sicurezza

Il client usa esclusivamente la publishable key Supabase. Non inserire mai una service-role key nell'app iOS o nel widget. L'accesso ai dati è filtrato dalle policy RLS in base all'utente autenticato.
