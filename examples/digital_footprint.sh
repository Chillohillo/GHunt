#!/bin/bash
# digital_footprint.sh - clone OSINT tools and perform self-research
# This script clones a large selection of OSINT repositories and runs
# searches using the provided personal data. It attempts basic
# self-recovery when errors occur.

set -euo pipefail

# Location of analysis directory
DIR="/home/chillo/dokumente/fussabdruck"
RESULTS="$DIR/results"
REPOS="$DIR/repos"
LOGS="$DIR/logs"

# Trap to handle most errors and attempt minor fixes
trap 'echo "[WARN] Error encountered. Attempting automatic fix..."; sudo apt-get -y --fix-broken install >/dev/null 2>&1 || true' ERR

mkdir -p "$RESULTS" "$REPOS" "$LOGS"
cd "$REPOS"

# --- Repository list (50+ entries) ---
REPOS_TO_CLONE=(
  "laramies/theHarvester" "OWASP/Amass" "sundowndev/phoneinfoga"
  "sherlock-project/sherlock" "smicallef/spiderfoot" "netbiosX/infoscan"
  "s0md3v/Photon" "megadose/twint" "thewhiteh4t/seeker"
  "khast3x/heartbleed" "darksearchio/darksearch-client" "megadose/ghunt"
  "s0md3v/ReconDog" "aboul3la/Sublist3r" "machawk1/wail"
  "userrecon/userrecon" "khast3x/lsassy" "multunus/email2phonenumber"
  "mxrch/GHunt" "thewhiteh4t/infoga" "Mebus/cupp"
  "vsec7/OSINT-search" "realslur/LinkedInScraper" "decalage2/oletools"
  "m8r0wn/Skiptracer" "twelvesec/osint" "asisnetworks/osintgram"
  "digerati/username-chooser" "viesystems/social-analyzer" "Whoisxmlapi/whois"
  "htr-tech/zphisher" "sundowndev/h8mail" "0xsha/OSINT-Tool"
  "dchrastil/Userrecon" "sch3m4/network-automation" "social-peek/socialscan"
  "osint8833/OSINT-Framework" "exiftool/exiftool" "botherder/facebook-osint"
  "FlameOfIgnis/whatsmyname" "Findomain/Findomain" "n0tr00t/Social-Engineer-Toolkit"
  "intelxapi/cli" "lampholder/lampyre" "mubix/CREDDUMP"
  "KassandraTeam/Recon" "jofpin/trape" "greenwolf/social_mapper"
  "soxoj/maigret" "SharadKumar97/OSINT-SPY" "martinvigo/email2phonenumber"
  "qeeqbox/social-analyzer" "Datalux/Osintgram" "milo2012/osintstalker"
  "HowToFind-bio/HowToFind" "sc1341/InstagramOSINT" "novitae/sterraxcyl"
)

for repo in "${REPOS_TO_CLONE[@]}"; do
  git clone --depth=1 "https://github.com/$repo.git" || true
done

cd "$DIR"

# --- Basic dependency setup ---
sudo apt-get update -y
sudo apt-get install -y python3-pip jq tor libimage-exiftool-perl || true

pip3 install --upgrade pip pipx || true
pipx install holehe || true
pipx install social-analyzer || true

# --- Personal data for searches ---
EMAILS=(
  "Marko.Hillebrand@gmx.de"
  "Marko.Hillebrand@yahoo.com"
  "Marko.Hillebrand@t-online.de"
  "mhillebrand87@gmail.com"
)

USERNAMES=(
  "mhillebrand87" "Marko.Hillebrand" "MarkoHillebrand"
  "Marko2212" "Marko221287" "Chillo" "Chillohillo"
)

PHONES=("+491726490000" "+4917677230437")

ADDRESSES=(
  "Heiligenstock 17, 42697 Solingen"
  "Königsteiner Str. 8, 45529 Hattingen"
  "Seilerweg 22, 45527 Solingen"
  "Hattinger Str. 783, 44879 Bochum"
)

AUSWEIS="L7ZY52YVK"
KFZ="SG-NM-2705"

# --- Email reconnaissance ---
echo "[*] Checking email breaches"
for email in "${EMAILS[@]}"; do
  holehe "$email" | tee "$RESULTS/holehe_${email}.txt" || true
  python3 "$REPOS/theHarvester/theHarvester.py" -e "$email" -b all | tee "$RESULTS/harvester_${email}.txt" || true
  python3 "$REPOS/h8mail/h8mail.py" -t "$email" -o "$RESULTS/h8mail_${email}.csv" || true
done

# --- Username reconnaissance ---
for user in "${USERNAMES[@]}"; do
  python3 "$REPOS/sherlock/sherlock/sherlock.py" "$user" | tee "$RESULTS/sherlock_${user}.txt" || true
  python3 -m social_analyzer "$user" --print-found --output "$RESULTS/social_${user}.json" || true
  maigret "$user" --print-found | tee "$RESULTS/maigret_${user}.txt" || true
done

# --- Phone number reconnaissance ---
for phone in "${PHONES[@]}"; do
  python3 "$REPOS/phoneinfoga/phoneinfoga.py" scan -n "$phone" | tee "$RESULTS/phoneinfoga_${phone}.txt" || true
  python3 "$REPOS/email2phonenumber/email2phonenumber.py" -n "$phone" | tee "$RESULTS/phone_lookup_${phone}.txt" || true
done

# --- Address and document searches ---
for addr in "${ADDRESSES[@]}"; do
  python3 "$REPOS/Photon/photon.py" -u "$addr" -o "$RESULTS/photon_${addr}" || true
  python3 "$REPOS/spiderfoot/sf.py" -q "$addr" | tee "$RESULTS/spiderfoot_${addr}.txt" || true
done

echo "$KFZ" > "$RESULTS/kfz.txt"

# --- Darknet searches (Tor required) ---
service tor start || true
python3 "$REPOS/Darkdump/darkdump.py" --query "Marko Hillebrand" --tor | tee "$RESULTS/darkdump_name.txt" || true
python3 "$REPOS/Darkdump/darkdump.py" --query "$AUSWEIS" --tor | tee "$RESULTS/darkdump_ausweis.txt" || true

# --- Image metadata extraction ---
find "$DIR" \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) -print0 | xargs -0 exiftool | tee "$RESULTS/exif.txt" || true

# --- Periodic log monitoring for missing modules ---
tail -n0 -F "$LOGS"/*.log 2>/dev/null | \
while read -r line; do
  if [[ "$line" == *"ModuleNotFoundError"* ]]; then
    mod=$(echo "$line" | grep -oP "No module named '\K[^']+")
    pip3 install "$mod" || true
  fi
done &

echo "[*] Digital footprint analysis finished. Results stored in $RESULTS"

