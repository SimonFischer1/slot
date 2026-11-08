# Nordlicht Slots

Responsive Slotmaschinen-Demo mit Supabase-Anmeldung, Animationen, Hebel, Autoplay, optionalen Soundeffekten und **virtuellen Demo-Credits**. Kein Echtgeld, keine Einzahlung und keine Auszahlung. Die Gewinnchance ist fest und für alle Spieler gleich; Admins können keine individuellen Quoten einstellen.

## Wichtig: Konto nicht gefunden / Spielen nicht möglich

Die aktuelle Datenbankmigration legt Profile für bereits registrierte Konten nachträglich an und repariert fehlende Profile beim Laden. Deshalb bitte die SQL-Datei nach dem Website-Update einmal vollständig erneut ausführen.

1. Öffne dein Supabase-Projekt → **SQL Editor → New query**.
2. Kopiere den vollständigen Inhalt von [`supabase.sql`](supabase.sql) hinein und drücke **Run**.
3. Prüfe, dass die Abfrage ohne Fehler durchgelaufen ist.
4. Lade die Website neu und melde dich erneut an. Bestehende Konten erhalten beim Nachtragen kein zusätzliches Startguthaben, damit bereits vorhandene Credits nicht überschrieben werden.

Die Website ist für das Supabase-Projekt `ltdnipeizdilscpqzirc` konfiguriert. Der Publishable Key in `index.html` ist ein öffentlicher Browser-Key; niemals einen `service_role`- oder Secret-Key veröffentlichen.

## Supabase Auth und GitHub Pages

- Supabase **Authentication → Sign In / Providers → Email** aktivieren.
- Unter **Authentication → URL Configuration** die veröffentlichte Website als Site URL und Redirect URL eintragen.
- GitHub Repository **Settings → Pages → Build and deployment → Deploy from a branch**, `main` und `/ (root)` auswählen. Die URL `https://simonfischer1.github.io/slot/` sollte außerdem in Supabase Redirect URLs stehen.
- Bei aktivierter E-Mail-Bestätigung muss der Link aus der Bestätigungsmail vor dem ersten Login geöffnet werden.

## Admin-Demo-Konto und Spielerverwaltung

1. Einmal mit dem gewünschten Admin-Konto registrieren und E-Mail bestätigen.
2. Supabase **SQL Editor** öffnen und die letzte, auskommentierte Admin-Zeile aus `supabase.sql` separat ausführen. Die E-Mail in der Zeile bei Bedarf anpassen.
3. Website neu laden und ab-/wieder anmelden. Im Konto-Dialog erscheinen Spielerliste und Credits-Verwaltung.
4. Eine positive Zahl schreibt virtuelle Credits gut; eine negative Zahl zieht Credits ab. Das Guthaben darf nicht unter null fallen.

**Keine personalisierte Glückssteuerung:** Das Admin-Panel kann und wird die Gewinnchance einzelner Spieler nicht ändern. Eine transparente, einheitliche Quote ist wichtig, damit Spielergebnisse nicht heimlich manipuliert werden.

## Wenn es danach noch nicht funktioniert

Die Seite zeigt jetzt konkrete Supabase-Fehler im Konto-Dialog. Kontrolliere in Supabase **Authentication → Users**, dass das Konto existiert und bestätigt ist, und im SQL Editor, ob die aktuelle Datei ohne Fehler ausgeführt wurde. Falls die Anmeldung klappt, aber SQL einen Fehler meldet, kopiere bitte nur den Fehlermeldungstext (keine Passwörter oder Secrets).

Passwörter, die in Chat, Code oder einem öffentlichen Repository geteilt wurden, bitte sofort ändern. Echtgeld-Glücksspiel erfordert je nach Markt Lizenzen und weitere rechtliche, technische und Spielerschutzmaßnahmen; dieses Projekt ist nur eine Demo.
