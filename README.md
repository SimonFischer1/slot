# Nordlicht Slots

Eine responsive Slotmaschinen-Demo mit Supabase-Anmeldung und **virtuellen Demo-Credits**. Das Projekt verarbeitet keine Echtgeld-Einzahlungen oder Auszahlungen. Die Spielwahrscheinlichkeiten sind fest und für alle gleich; es gibt keine Admin-Funktion zum Verändern der Gewinnchancen.

## Supabase einrichten

1. Öffne dein Supabase-Projekt und gehe zu **SQL Editor → New query**.
2. Kopiere den vollständigen Inhalt von [`supabase.sql`](supabase.sql) hinein und führe ihn aus.
3. In `supabase.sql` ist der Browser-Client bereits auf dieses Projekt eingestellt: `ltdnipeizdilscpqzirc`. Der Publishable Key in `index.html` ist ein öffentlicher Client-Key; **niemals** einen `service_role`- oder Secret-Key in eine HTML-Datei eintragen.
4. Veröffentliche `index.html` mit GitHub Pages: Repository **Settings → Pages → Build and deployment → Deploy from a branch**, dann Branch `main` und Ordner `/ (root)` auswählen und speichern. Nach dem Deployment zeigt GitHub Pages die Website-URL an.

## Registrierung und Anmeldung

Neue Konten werden beim Registrieren in `auth.users` angelegt. Der Datenbank-Trigger erzeugt automatisch ein Profil mit 1.000 virtuellen Credits. Wenn E-Mail-Bestätigung im Supabase-Projekt aktiviert ist, muss der Bestätigungslink zuerst angeklickt werden. Für den produktiven Einsatz sollte die Bestätigung aktiviert bleiben.

Falls die Registrierung scheitert, kontrolliere in Supabase:

- **Authentication → Providers → Email** ist aktiviert.
- **Authentication → URL Configuration** enthält die veröffentlichte Website unter **Site URL** sowie bei **Redirect URLs**.
- `supabase.sql` wurde ohne Fehler ausgeführt; unter **Table Editor** existiert `profiles`.
- Unter **Authentication → Users** ist das Konto vorhanden. Existiert es bereits, führt das SQL-Backfill das Profil beim erneuten Ausführen des Skripts nach.

## Admin-Konto

1. Registriere dein Konto und bestätige die E-Mail.
2. Öffne den Supabase SQL Editor und führe die unten in `supabase.sql` kommentierte `UPDATE public.profiles ...`-Anweisung separat aus. Passe die E-Mail bei Bedarf an.
3. Melde dich auf der Website ab und wieder an. Im Konto-Dialog erscheint dann die Admin-Funktion, um **virtuelle Demo-Credits** gutzuschreiben.

## Sicherheit und Hosting

Der Publishable Key ist für Browser-Apps gedacht; der Schutz erfolgt durch Row Level Security und serverseitige RPC-Funktionen. Keine Passwörter oder Secret-/Service-Role-Keys in GitHub commiten. Ändere Passwörter sofort, falls sie in Chat, Code oder einem öffentlichen Repository geteilt wurden.

GitHub Pages hostet nur statische Dateien. Echtgeld-Glücksspiel benötigt je nach Markt unter anderem Genehmigungen, Alters-/Identitätsprüfungen, Zahlungs- und Spielerschutzmaßnahmen sowie rechtliche Prüfung. Dieses Repository ist deshalb ausdrücklich eine kostenlose Demo und keine Echtgeld-Casino-Plattform.
