# Guix og Hoot på Debian 13 (Trixie)

Status pr. 23. november 2026. Guiden er skrevet til næste Codex-session
og kan også bruges som brugervejledning.

## Kort status

- Guix er installeret ved siden af Debian Trixie.
- Guix 1.5 bruger den dedikerede, uprivilegerede konto `guix-daemon`.
- Der er ingen `guixbuild`-gruppe i Guix 1.5, og det er korrekt.
- `guix-daemon` kører, og klienten kan kommunikere over
  `/var/guix/daemon-socket/socket`.
- Brugeren har kørt `guix pull`.
- Den pulled Guix-profil er
  `~/.config/guix/current`, med commit
  `1e8d0825c5e7ba03b38a775083bef27209650d0e`.
- Den pulled pakkekatalog viser `guile-hoot` 0.10.0.
- Hoot 0.10.0 er endnu ikke bekræftet startet og testet.
- En tidligere `guix shell` brugte den gamle Guix fra
  `/usr/local/bin/guix`, som hentede Hoot 0.7.0. Det skyldes
  sandsynligvis, at en ny terminal i den eksisterende desktop-session
  havde den gamle PATH.
- `glibc-locales`-hintet er informativt og er ikke en fejl.
- `bash: dircolors: command not found` i et `--pure`-shell er harmløst.

## Hvad opsætningen betyder

Opsætningen består af tre lag:

1. **Guix-systemet** i `/gnu/store` og `/var/guix` med
   `guix-daemon`, som henter og bygger pakker.
2. **Brugerens Guix-klient** i `~/.config/guix/current`, oprettet af
   `guix pull`. Det er den, som kender Hoot 0.10.0.
3. **Det midlertidige Hoot-miljø**, som `guix shell` opretter. Hoot
   installeres ikke permanent i Debian, og kommandoen forsvinder fra
   PATH, når shellen afsluttes. Pakkerne forbliver i Guix-storen.

Det er derfor ikke nødvendigt at kompilere Guile manuelt for at bruge
Hoot. Guix leverer den nødvendige Guile og Hoot i det midlertidige
miljø.

## Vigtigt om terminalens PATH

Kontrollér i den terminal, hvor Hoot skal bruges:

```bash
command -v guix
guix --version
guix describe
```

Den korrekte sti er:

```text
/home/kristiannj/.config/guix/current/bin/guix
```

`guix --version` skal vise en Git-revision som `1e8d082`, ikke
`GNU Guix 1.5.0`.

Hvis terminalen stadig bruger `/usr/local/bin/guix`, så indlæs
profilen og ryd Bash' kommandocache:

```bash
source /etc/profile.d/zzz-guix.sh
hash -r
command -v guix
```

En hel logout/login vil også opdatere PATH for den næste
desktop-session. En ny terminal i en gammel session kan derimod arve
den gamle PATH.

## Næste skridt

Bekræft først, at pakkekataloget viser 0.10.0:

```bash
guix show guile-hoot
```

Åbn derefter det midlertidige Hoot-miljø:

```bash
guix shell --pure guile guile-hoot
```

Inde i miljøet:

```bash
hoot --version
printf '(display 42)\n' > /tmp/hoot-smoke.scm
hoot compile --run /tmp/hoot-smoke.scm
```

Forventet resultat:

```text
hoot (Hoot) 0.10.0
42
```

Forlad miljøet med:

```bash
exit
```

Hvis `dircolors`-fejlen er irriterende, kan Guix-shellet startes med
et rent Bash-miljø:

```bash
guix shell --pure guile guile-hoot -- bash --noprofile --norc
```

Dette ændrer ikke Hoot-installationen; det undgår kun hostens
Bash-startfiler.

## Checkliste

- [x] Installér Guix ved siden af Debian Trixie
- [x] Kontrollér `guix-daemon`
- [x] Kør `guix pull` som normal bruger
- [x] Bekræft at pakkekataloget indeholder Hoot 0.10.0
- [ ] Bekræft at terminalen bruger `~/.config/guix/current/bin/guix`
- [ ] Start Hoot 0.10.0 i et `guix shell --pure`
- [ ] Kør `hoot compile --run /tmp/hoot-smoke.scm`
- [ ] Beslut om `glibc-locales` skal installeres
- [ ] Beslut om den lokale 0.10.0-kildekode skal bygges til udvikling

## Valgfrit: Locale

Hvis et Guix-program klager over manglende locale, kan
`glibc-locales` installeres:

```bash
guix install glibc-locales
export GUIX_LOCPATH="$HOME/.guix-profile/lib/locale"
```

En ny login-shell bør derefter indlæse profilen. Hoot kræver ikke
denne ændring for at blive afprøvet.

## Valgfrit: Byg den lokale Hoot-kildekode

Guix-pakken er tilstrækkelig til almindelig brug. Byg kun fra dette
træ, hvis du vil udvikle eller ændre Hoot:

```bash
cd /home/kristiannj/projects/guile-hoot-0.10.0
guix shell --pure
./bootstrap.sh
./configure
make -j2
make check
./pre-inst-env hoot --version
```

## Kendte faldgruber

- Kør ikke installationsscriptet igen; Guix er allerede installeret.
- Manglende `guixbuild` er ikke en fejl i Guix 1.5.
- Kør ikke Guix-kommandoer med `sudo`.
- Brug `guix shell --pure` for at undgå hostens Guile- og
  PKG-config-variabler.
- Kontrollér `command -v guix`, når en ny terminal henter Hoot 0.7.0
  i stedet for 0.10.0.
- `install.txt` er en untracked fil fra brugerens tidligere
  fejlfinding. Den skal bevares, medmindre brugeren beder om andet.

## Git-status

Repositoryet er på branch `trunk`. Det første commit er:

```text
2c62346725add8ccbbd5f195ac312bfd3bf35124
Add Guix setup guide and agent attribution policy
```

Commitet indeholder:

- `AGENTS.md`
- `GUIX-TRIXIE-HOOT.md`
- `install-guix-trixie.sh`

De oprindelige Hoot-projektfiler er fortsat untracked, fordi
repositoryet blev initialiseret sent. Tilføj ikke hele træet ved et
uheld.

`AGENTS.md` kræver begge følgende trailers ved commits:

```text
Co-authored-by: OpenAI Codex <codex@openai.com>
Co-authored-by: DeepSeek <noreply@deepseek.com>
```

Agentens tidligere `.git`-skrivefejl skyldtes en read-only sandkasse.
Brugeren har selv kunnet gennemføre amend. Hvis agenten senere skal
committe, skal skriveadgang til `.git` verificeres først.

## Handover-prompt til næste session

Kopier hele teksten nedenfor som første besked i den næste session.

```text
Vi fortsætter opsætningen af Guix og Hoot på Debian 13 Trixie i
/home/kristiannj/projects/guile-hoot-0.10.0.

Læs først AGENTS.md, README.md, GUIX-TRIXIE-HOOT.md og TODO.md.
Fortsæt fra den aktuelle tilstand; gentag ikke Guix-installationen.

Status:
- Guix 1.5 er installeret ved siden af Debian.
- guix-daemon kører som den dedikerede guix-daemon-bruger.
- Guix 1.5 har ikke guixbuild, og det er korrekt.
- Brugeren har kørt guix pull.
- Den pulled Guix-profil kender Hoot 0.10.0.
- En tidligere shell brugte /usr/local/bin/guix 1.5.0 og hentede
  Hoot 0.7.0. Det var den gamle PATH, ikke en installationsfejl.
- Hoot 0.10.0 er endnu ikke bekræftet kørende.

Første opgave:
1. Få brugeren til at køre:
   source /etc/profile.d/zzz-guix.sh
   hash -r
   command -v guix
   guix --version
   guix describe
   guix show guile-hoot
2. Bekræft, at stien er
   /home/kristiannj/.config/guix/current/bin/guix,
   at revisionen ikke er 1.5.0, og at guile-hoot vises som 0.10.0.
3. Kør derefter i brugerens terminal:
   guix shell --pure guile guile-hoot
   hoot --version
   printf '(display 42)\n' > /tmp/hoot-smoke.scm
   hoot compile --run /tmp/hoot-smoke.scm
4. Forvent hoot 0.10.0 og output 42.

Vigtigt:
- Kør ikke Guix-kommandoer med sudo.
- guix-daemon skal fortsat køre som guix-daemon-brugeren.
- Locale-hintet om glibc-locales er ikke blokerende.
- dircolors: command not found under --pure er harmløst.
- Brug --pure for at undgå hostens Guile- og PKG-config-variabler.
- Agentens shell kan fortsat vise /usr/local/bin/guix og Hoot 0.7.0;
  brug brugerens terminal eller den absolutte pulled Guix-sti ved
  diagnostik.
- Agenten har ikke netværksadgang til at hente Hoot-substitutter.
- .git var read-only for agenten; hvis commit kræves, skal adgang
  kontrolleres.
- Hvis commit udføres, skal AGENTS.md's to Co-authored-by-trailers
  begge med.

Byg kun den lokale Hoot-kildekode, hvis brugeren vil udvikle Hoot.
Guix-pakken 0.10.0 er den anbefalede vej til almindelig brug.
```
