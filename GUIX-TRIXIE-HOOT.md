# Guix og Hoot på Debian 13 (Trixie)

Denne guide installerer Guix ved siden af Debian og bagefter Hoot i et
Guix-miljø. Den erstatter ikke `apt`, `dpkg` eller Trixies system-Guile.
Guiden forudsætter:

- Debian 13 (Trixie) på `x86_64`
- en normal installation med `systemd`
- internetadgang og mulighed for at bruge `sudo`
- helst mindst 20 GiB ledig plads på det filsystem, der indeholder `/`

Guix kan også installeres på andre arkitekturer, men filnavne og
substitutter afhænger af arkitekturen. Den officielle installer klarer
den forskel.

## Hvorfor den officielle installer?

Trixies Debian-arkiv indeholder ikke en `guix`-pakke, man kan installere
med `apt install guix`. Derfor bruges Guix' officielle
installationsscript.

Undgå at aktivere Debian testing eller unstable alene for at få Hoot.
Det blander pakkebaserede systemafhængigheder ind i en Trixie-installation
og er en unødvendig risiko. Guix kan leve side om side med Debian og
levere den nødvendige nyere Guile uden at ændre Trixies pakker.

Installationen opretter primært følgende:

- `/gnu/store`: Guix' pakkestore
- `/var/guix`: daemon-data og profiler
- `guix-daemon.service`: systemd-tjenesten, som udfører builds
- en dedikeret `guix-daemon`-bruger i Guix 1.5 og nyere
- ældre Guix-versioner kan i stedet bruge `guixbuild` og `guixbuilderNN`
- en profilfil under `/etc/profile.d/`, typisk `zzz-guix.sh` i Guix 1.5

Guix-pakker installeres som udgangspunkt uden at overskrive filer, som
Trixie ejer.

## 1. Kontrollér systemet

Kontrollér først, at du er på Trixie og den forventede arkitektur:

```bash
cat /etc/os-release
uname -m
```

Ved `uname -m` skal en normal PC med Intel/AMD vise `x86_64`.

Kontrollér ledig plads og tid:

```bash
df -h /
timedatectl
```

Guix' første `guix pull` samt eventuelle builds kan fylde en del. Er der
under cirka 10 GiB ledigt, bør du frigøre plads først. 20 GiB eller mere
er mere komfortabelt.

Hvis klokken er forkert, kan signaturkontroller og HTTPS fejle. Sørg for,
at NTP er aktiv:

```bash
sudo timedatectl set-ntp true
timedatectl
```

## 2. Installér forudsætninger

```bash
sudo apt update
sudo apt install ca-certificates curl wget gnupg xz-utils
```

Kontrollér værktøjerne:

```bash
command -v curl
command -v wget
command -v gpg
command -v tar
command -v xz
```

Hvis en af kommandoerne ikke findes, skal den mangle installeres, før du
fortsætter.

## 3. Hent Guix' officielle installer

Hent kun installeren fra Guix' officielle GNU Savannah-adresse:

> Der ligger også et gennemgåeligt wrapper-script i
> [`install-guix-trixie.sh`](install-guix-trixie.sh). Det kan udføre
> trin 1-4 og stoppe til gennemsyn, før den officielle installer køres
> som root. Se afsnittet [Brug installationsscriptet](#brug-installationsscriptet).

```bash
installer_dir="$(mktemp -d)"
cd "$installer_dir"

curl --fail --location --remote-name \
  https://git.savannah.gnu.org/cgit/guix.git/plain/etc/guix-install.sh

chmod 700 guix-install.sh
```

Læs scriptet igennem, før det køres som root:

```bash
less guix-install.sh
```

Installer Guix:

```bash
sudo ./guix-install.sh
```

Installationsscriptet henter og signaturkontrollerer Guix-binæren,
opretter build-brugerne, installerer systemd-tjenesten og tilføjer
Guix-opsætningen til `/etc/profile.d/`. Læs eventuelle spørgsmål og
advarsler, og afbryd, hvis adresser eller signaturer ikke ser rigtige ud.

Det kan tage tid, fordi Guix initialiserer sin pakkestore og profil.

### Brug installationsscriptet

Scriptet skal køres som din normale bruger, ikke med `sudo`:

```bash
cd /home/kristiannj/projects/guile-hoot-0.10.0
./install-guix-trixie.sh --dry-run
./install-guix-trixie.sh
```

Først vises kontroller og planlagte handlinger uden at ændre systemet.
Den rigtige kørsel beder om din sudo-adgangskode i terminalen,
installerer forudsætningerne og henter Guix-installeren. Du får derefter
lejlighed til at gennemgå installeren, og installationen starter kun,
hvis du skriver `RUN`.

Adgangskoden indtastes direkte i `sudo`s prompt. Den skal ikke gemmes i
scriptet eller sendes til en anden person.

Hvis installationen allerede er gennemført, kan den kontrolleres uden at
køre installerens systemændringer igen:

```bash
./install-guix-trixie.sh --verify-only
```

## 4. Kontrollér Guix-daemonen

Åbn en ny login-shell. I Guix 1.5 indlæses profilfilen automatisk:

```bash
exec bash --login
```

Kontrollér installationen:

```bash
guix --version
sudo systemctl status guix-daemon --no-pager
getent passwd guix-daemon
guix gc --list-roots
```

Guix 1.5 og nyere bruger den dedikerede, uprivilegerede konto
`guix-daemon`; der er ikke længere en `guixbuild`-gruppe. `guix gc
--list-roots` viser, at klienten kan kommunikere med daemonen.

Ældre Guix-installationer kan i stedet kontrolleres med:

```bash
getent group guixbuild
getent passwd | awk -F: '$1 ~ /^guixbuilder/ { print $1 }' | sort
```

Hvis tjenesten ikke er aktiv:

```bash
sudo systemctl enable --now guix-daemon
sudo systemctl restart guix-daemon
sudo systemctl status guix-daemon --no-pager
```

Hvis den stadig fejler, så læs de nyeste loglinjer:

```bash
journalctl -u guix-daemon -b --no-pager
```

## 5. Initialisér Guix som din normale bruger

Kør ikke `guix pull` eller `guix install` med `sudo`. Den normale bruger
skal have sin egen Guix-profil:

```bash
exec bash --login
command -v guix
guix pull
```

`guix pull` henter Guix selv og de standardkanaler til
`~/.config/guix/current`. Første kørsel er typisk den langsomste.

Når den er færdig:

```bash
hash -r
guix describe
```

Kommandoen bør vise den Guix-revision, du netop har hentet.

### Hvis programmer klager over locale

Debian og Guix har hver deres locale-database. Hvis et Guix-program
rapporterer en manglende locale:

```bash
guix install glibc-locales
export GUIX_PROFILE="$HOME/.guix-profile"
. "$GUIX_PROFILE/etc/profile"
```

Åbn derefter en ny login-shell. Dette bør ikke være nødvendigt for Hoot,
men det er et almindeligt friktionspunkt på en fremmed distribution.

## 6. Installér og prøv Hoot

Brug et isoleret Guix-shell frem for at installere Hoot i din
systemprofil. Det er nemt at afprøve og holder Trixies environment ude
af billedet:

```bash
guix shell --pure guile guile-hoot
```

Inde i shellen:

```bash
guile --version
hoot --version
hoot --help
```

`--pure` er vigtig. Den fjerner hostens `GUILE_LOAD_PATH`,
`GUILE_LOAD_COMPILED_PATH`, `PKG_CONFIG_PATH` og lignende variabler, som
ellers kan få Guix-værktøjerne til at blande Trixies Guile og Guix'
Guile sammen.

Kør en lille funktionel test:

```bash
printf '(display 42)\n' > /tmp/hoot-smoke.scm
hoot compile --run /tmp/hoot-smoke.scm
```

Programmet skal udskrive `42`. Gå ud af Guix-shellen med:

```bash
exit
```

## 7. Vælg en permanent arbejdsform

Til lejlighedsvis brug er `guix shell --pure guile guile-hoot` den
mindst invasive løsning.

Vil du have `guile` og `hoot` tilgængelige i alle nye shells, kan de
installeres i din brugerprofil:

```bash
guix install guile guile-hoot
exec bash --login
hoot --version
```

Dette påvirker kun din Guix-profil under hjemmebiblioteket, ikke
Debian-systemet.

### Fast miljø til et projekt

Til et projekt kan du gemme afhængighederne i en `manifest.scm`:

```scheme
(use-modules (guix profiles)
             (gnu packages guile)
             (gnu packages guile-xyz))

(specifications->manifest
 '("guile"
   "guile-hoot"))
```

Kør derefter følgende fra projektbiblioteket:

```bash
guix shell --pure -m manifest.scm
```

Det gør miljøet lettere at genskabe senere.

## 8. Byg den lokale Hoot-0.10.0-kildekode

Brug kun denne vej, hvis du skal arbejde med netop dette kildekodetræ.
Hoot-pakken fra Guix er lettere at bruge til almindelig brug.

```bash
cd /home/kristiannj/projects/guile-hoot-0.10.0
guix shell --pure
./bootstrap.sh
./configure
make -j2
make check
./pre-inst-env hoot --version
```

Guix-shellet læser projektets `guix.scm` og leverer både build-værktøjer
og den nødvendige nyere Guile. Du behøver derfor ikke overskrive eller
opgradere Trixies `guile-3.0`-pakke.

Hvis `make -j2` er for langsomt, kan tallet øges, men høj parallelitet
kræver mere RAM.

## Fejlfinding

### `guix: command not found`

Indlæs profilfilen og kontrollér, at den aktuelle Guix-profil findes:

```bash
if [[ -r /etc/profile.d/zzz-guix.sh ]]; then
    . /etc/profile.d/zzz-guix.sh
elif [[ -r /etc/profile.d/guix.sh ]]; then
    . /etc/profile.d/guix.sh
fi
command -v guix
ls -l ~/.config/guix/current/bin/guix
```

Start derefter en helt ny login-shell. Installationsscriptets ændringer
slår ikke nødvendigvis igennem i en terminal, som allerede var åben.

### `cannot connect to daemon` eller `permission denied` ved build

Kontrollér først tjenesten og build-brugerne:

```bash
sudo systemctl status guix-daemon --no-pager
getent passwd guix-daemon
guix gc --list-roots
```

Kør normalt ikke Guix-kommandoer med `sudo`; det er kun
installationsscriptet og systemtjenester, der skal køres som root.

Hvis `getent passwd guix-daemon` giver et resultat, er det den moderne
Guix-model. Manglende `guixbuild` er da ikke en fejl.

Hvis tjenesten ikke kan kommunikere med klienten, kan du køre Guix'
officielle installationsscript igen fra samme officielle kilde og læse
dets output.

### Hostens Guile forstyrrer

Brug `--pure` og kontrollér, hvilken Hoot der faktisk startes:

```bash
guix shell --pure guile guile-hoot
command -v hoot
hoot --version
```

Undgå i den sammenhæng at eksportere `GUILE_LOAD_PATH`,
`GUILE_LOAD_COMPILED_PATH`, `PKG_CONFIG_PATH`, `CPATH`,
`C_INCLUDE_PATH` eller `LIBRARY_PATH` fra Debian-miljøet.

### Download eller substitutter fejler

Kontrollér tid, DNS og eventuelle HTTP-proxier:

```bash
timedatectl
getent hosts ftp.gnu.org
env | grep -i '_proxy'
```

Hvis klokken er rigtig, og hosten kan nå internettet, kan du prøve en ny
`guix pull`. Undgå `--no-substitutes`, medmindre du er indstillet på at
kompilere meget fra bunden.

### Pakken `guile-hoot` findes ikke

Opdatér kanalerne og søg igen:

```bash
guix pull
guix search guile-hoot
guix show guile-hoot
```

Den installerede Hoot-version kan afvige fra versionen i dette
kildekodetræ. Kontrollér altid med:

```bash
guix shell --pure guile guile-hoot -- hoot --version
```

Hvis du specifikt skal bruge 0.10.0 fra dette træ, så byg det lokalt som
beskrevet i afsnit 8.

### Pladsen løber ud

Se hvor Guix bruger plads:

```bash
du -sh /gnu/store /var/guix 2>/dev/null
df -h /
```

Frigør plads uden for `/gnu` og `/var/guix`, eller flyt Guix-storen til
et større filsystem efter Guix' officielle anvisninger. Slet ikke vilkårlige
stier i `/gnu/store`; Guix håndterer storen som en delt, immutable cache.

## Endelig kontrol

Følgende bør alle fungere:

```bash
guix describe
guix shell --pure guile guile-hoot -- hoot --version
guix shell --pure guile guile-hoot -- sh -c \
  'printf "(display 42)\n" > /tmp/hoot-smoke.scm &&
   hoot compile --run /tmp/hoot-smoke.scm'
```

Den sidste kommando skal udskrive `42`.

Hoot-projektets egne krav og installationsveje er beskrevet i
[README.md](README.md).
