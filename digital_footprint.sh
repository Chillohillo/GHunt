#!/bin/bash
# digital_footprint.sh - aggregate OSINT tools for self-analysis

set -euo pipefail

# Automatic fix if a command fails
trap 'echo "[WARN] Command failed. Attempting repair..."; sudo apt-get install --fix-broken -y; true' ERR

# Base directory for all output and repositories
BASE_DIR="/home/chillo/dokumente/fussabdruck"
RESULTS_DIR="$BASE_DIR/results"
REPOS_DIR="$BASE_DIR/repos"
LOGS_DIR="$BASE_DIR/logs"

mkdir -p "$RESULTS_DIR" "$REPOS_DIR" "$LOGS_DIR"
cd "$REPOS_DIR"

# ------------------------------------------------------------
# Clone a curated list of public OSINT repositories
# Duplicate entries are automatically skipped if the folder exists
# ------------------------------------------------------------
REPOS=(
  "laramies/theHarvester" "OWASP/Amass" "sundowndev/phoneinfoga"
  "sherlock-project/sherlock" "smicallef/spiderfoot" "netbiosX/infoscan"
  "s0md3v/Photon" "megadose/twint" "thewhiteh4t/seeker" "khast3x/heartbleed"
  "darksearchio/darksearch-client" "megadose/ghunt" "s0md3v/ReconDog"
  "aboul3la/Sublist3r" "machawk1/wail" "userrecon/userrecon" "khast3x/lsassy"
  "multunus/email2phonenumber" "mxrch/GHunt" "thewhiteh4t/infoga" "Mebus/cupp"
  "vsec7/OSINT-search" "realslur/LinkedInScraper" "decalage2/oletools"
  "m8r0wn/Skiptracer" "twelvesec/osint" "asisnetworks/osintgram"
  "digerati/username-chooser" "viesystems/social-analyzer" "Whoisxmlapi/whois"
  "htr-tech/zphisher" "sundowndev/h8mail" "0xsha/OSINT-Tool"
  "dchrastil/Userrecon" "sch3m4/network-automation" "social-peek/socialscan"
  "osint8833/OSINT-Framework" "exiftool/exiftool" "botherder/facebook-osint"
  "FlameOfIgnis/whatsmyname" "Findomain/Findomain" "n0tr00t/Social-Engineer-Toolkit"
  "intelxapi/cli" "lampholder/lampyre" "mubix/CREDDUMP" "KassandraTeam/Recon"
  "jofpin/trape" "greenwolf/social_mapper" "soxoj/maigret" "SharadKumar97/OSINT-SPY"
  "martinvigo/email2phonenumber" "qeeqbox/social-analyzer" "Datalux/Osintgram"
  "milo2012/osintstalker" "HowToFind-bio/HowToFind" "sc1341/InstagramOSINT"
  "novitae/sterraxcyl" "jivoi/awesome-osint" "Frikallo/footprint" "lanmaster53/recon-ng"
  "laramies/metagoofil" "0xbharath/datasploit" "darkoperator/dnsrecon"
  "pownjs/pown-osint" "GoSecure/dnsenum" "ZephrFish/GoogPwn" "botherder/dnscan"
  "wesleybranton/whoisxmlapi" "ThreatHunter-IO/credninja" "m8r0wn/xlink"
  "harleo/ghunt2" "digitalhunt/digitalhunt" "megadose/hackrecover"
  "graphqlmap/graphqlmap" "12Foxes/dossier" "soxoj/maigret-scripts"
  "k4m4/terminals-are-sexy" "MisterBianco/KSVD" "JusticeRookie/OSINT.py"
  "vaginessa/osint-spy" "michenriksen/aquatone" "netbiosX/DCOM" "projectdiscovery/nuclei"
  "trailofbits/algo" "OWASP/SecLists" "0xdic/fosint" "saintdle/TrustTrees"
  "soxoj/LeakLookupScripts" "maurosoria/dirsearch" "projectdiscovery/subfinder"
  "exp0se/nameserver-analysis" "cgboal/pssh" "nyxgeek/knock" "chrisallenlane/cheat.sh"
)

for repo in "${REPOS[@]}"; do
  name="$(basename "$repo")"
  if [ -d "$name" ]; then
    echo "[INFO] $name already exists, skipping."
    continue
  fi
  git clone --depth=1 "https://github.com/$repo.git" "$name" || echo "[WARN] Failed to clone $repo"
 done

# ------------------------------------------------------------
# Install system and Python dependencies
# ------------------------------------------------------------
echo "[INFO] Installing dependencies"
sudo apt-get update -y
sudo apt-get install -y python3-pip jq tor git libimage-exiftool-perl

pip3 install --upgrade pip pipx
pipx install holehe || true
pipx install social-analyzer || true

# Install Python requirements from all cloned repositories if present
find "$REPOS_DIR" -name requirements.txt -exec pip3 install -r {} \; > "$LOGS_DIR/pip_install.log" 2>&1 || true

cd "$BASE_DIR"

# ------------------------------------------------------------
# Define personal data for searches (user provided)
# ------------------------------------------------------------
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
ID_NUMBER="L7ZY52YVK"
LICENSE_PLATE="SG-NM-2705"

# ------------------------------------------------------------
# Run selected OSINT tools with the provided data
# ------------------------------------------------------------
echo "[INFO] Running email investigations"
for email in "${EMAILS[@]}"; do
  holehe "$email" | tee "$RESULTS_DIR/holehe_${email}.txt"
  python3 "$REPOS_DIR/theHarvester/theHarvester.py" -e "$email" -b all | tee "$RESULTS_DIR/harvester_${email}.txt"
  python3 "$REPOS_DIR/h8mail/h8mail.py" -t "$email" -o "$RESULTS_DIR/h8mail_${email}.csv"
done

echo "[INFO] Investigating usernames"
for user in "${USERNAMES[@]}"; do
  python3 "$REPOS_DIR/sherlock/sherlock/sherlock.py" "$user" | tee "$RESULTS_DIR/sherlock_${user}.txt"
  maigret "$user" --print-found | tee "$RESULTS_DIR/maigret_${user}.txt"
done

echo "[INFO] Investigating phone numbers"
for phone in "${PHONES[@]}"; do
  python3 "$REPOS_DIR/phoneinfoga/phoneinfoga.py" scan -n "$phone" | tee "$RESULTS_DIR/phone_${phone}.txt"
done

echo "[INFO] Investigating addresses"
for addr in "${ADDRESSES[@]}"; do
  python3 "$REPOS_DIR/Photon/photon.py" -u "$addr" -o "$RESULTS_DIR/photon_${addr}"
done

# Dark web search via Tor
 echo "[INFO] Searching the dark web"
 sudo service tor start
 python3 "$REPOS_DIR/Darkdump/darkdump.py" --query "Marko Hillebrand" --tor | tee "$RESULTS_DIR/darkdump_name.txt"
 python3 "$REPOS_DIR/Darkdump/darkdump.py" --query "$ID_NUMBER" --tor | tee "$RESULTS_DIR/darkdump_id.txt"

# Exif data from local images
 echo "[INFO] Extracting local image metadata"
 find "$BASE_DIR" -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' | while read -r img; do
  exiftool "$img" | tee -a "$RESULTS_DIR/exif_metadata.txt"
 done

echo "[INFO] GitHub repository lookup"
for user in "${USERNAMES[@]}"; do
  gh repo list "$user" --limit 50 | tee "$RESULTS_DIR/github_${user}.txt"
done

echo "$LICENSE_PLATE" > "$RESULTS_DIR/license_plate.txt"

echo "[INFO] OSINT collection finished. Check results in $RESULTS_DIR"
