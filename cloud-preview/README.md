# Diario temperatura — Cloud preview

Questa directory contiene una nuova PWA separata per testare sincronizzazione cloud. Non sostituisce la PWA pubblicata su GitHub Pages da `main`.

## Backend
- Supabase project: `muuihmayqnvzugomfwlq` (regione EU Central).
- Auth email/password.
- Tabelle `fever_measurements` e `fever_episodes`, RLS attiva e isolamento per proprietario.
- Nel browser è presente solo la publishable key; nessuna service-role key.

## Deploy
La preview va pubblicata separatamente (es. Cloudflare Pages project distinto) puntando questa directory/branch. Non cambiare il source GitHub Pages esistente.

## Stato
Prototipo iniziale: login, registrazione, misurazioni CRUD essenziali, archiviazione episodi. Migrazione dati, export/import, grafico e widget iOS sono ancora da implementare.
