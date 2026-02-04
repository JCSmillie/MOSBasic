#!/bin/zsh

################################################################
#
#	iosdump.sh  (tvOS dump)
#		Script pulls all tvOS devices from Mosyle and sorts them out
#		into other files. These files are utilized after the
#		fact by other scripts.
#
#		JCS - 9/28/2021  -v2
#   PATCHED - 02/04/2026
#
#   Fixes:
#   - Valid JSON post body (array specific_columns)
#   - Sanitize Bearer token
#   - Normalize wrapped/unwrapped Mosyle JSON responses
#   - Strip trailing '%' seen in output
#   - Option A end-of-list detection: status==OK and devices==[]
#   - Remove cut/sed JSON corruption
#
################################################################

source "$BAGCLI_WORKDIR/config"
source "$BAGCLI_WORKDIR/common"
IFS=$'\n'

DATECODEFORFILE=$(date '+%Y-%m-%d_%H:%M')
CMDRAN="iOSdump"

if [ "$MB_DEBUG" = "Y" ]; then
	echo "Variable 1-> $1"
	echo "Variable 2-> $2"
	echo "Variable 3-> $3"
	echo "Variable 4-> $4"
fi

#################################
#            Functions          #
#################################

Generate_JSON_TVOSDUMPPostData() {
cat <<EOF
{
  "accessToken": "$MOSYLE_API_key",
  "options": {
    "os": "tvos",
    "page": "$THEPAGE",
    "specific_columns": [
      "deviceudid",
      "serial_number",
      "device_name",
      "tags",
      "asset_tag",
      "userid",
      "enrollment_type",
      "username",
      "date_app_info"
    ],
    "page_size": "1000"
  }
}
EOF
}

# Normalize Mosyle JSON so json2csv always sees top-level "devices"
Normalize_Mosyle_Devices_JSON() {
  local INFILE="$1"
  local OUTFILE="$2"

  python3 - "$INFILE" "$OUTFILE" <<'PY'
import json, sys

inp, outp = sys.argv[1], sys.argv[2]
raw = open(inp, "r", encoding="utf-8", errors="replace").read().strip()

# Mosyle sometimes appends a stray '%'
if raw.endswith('%'):
    raw = raw[:-1].rstrip()

try:
    data = json.loads(raw)
except Exception:
    with open(outp, "w", encoding="utf-8") as f:
        f.write(raw + "\n")
    sys.exit(2)

# Unwrap {"status":"OK","response":{...}} if present
if isinstance(data, dict) and isinstance(data.get("response"), dict):
    data = data["response"]

# Always write clean JSON + newline
with open(outp, "w", encoding="utf-8") as f:
    json.dump(data, f)
    f.write("\n")
PY
}

# Option A: last page detection for devices
# Return code 0 => YES last page (status OK + devices empty list)
IsLastDevicesPage() {
  local FILE="$1"
  python3 - "$FILE" <<'PY'
import json, sys
p=sys.argv[1]
raw=open(p,"r",encoding="utf-8",errors="replace").read().strip()
if raw.endswith('%'):
    raw = raw[:-1].rstrip()
d=json.loads(raw)

devices = d.get("devices", None)
status  = d.get("status", "")

if status == "OK" and isinstance(devices, list) and len(devices) == 0:
    sys.exit(0)
sys.exit(1)
PY
}

################################
#            DO WORK           #
################################

# Default output path if not set in config
if [ -z "$TEMPOUTPUTFILE_MERGEDTVOS" ]; then
	TEMPOUTPUTFILE_MERGEDTVOS="/tmp/Mosyle_active_tvOS_Tagz_MergedATVs.txt"
	cli_log "No path specified. Sending data to $TEMPOUTPUTFILE_MERGEDTVOS"
else
	cli_log "TEMPOUTPUTFILE_MERGEDTVOS has been set to $TEMPOUTPUTFILE_MERGEDTVOS"
fi

# Backup existing dump if present
if [ -s "$TEMPOUTPUTFILE_MERGEDTVOS" ]; then
	cli_log "Creating copy of current dump---> /tmp/Current-$DATECODEFORFILE.MosyleTVosDump.txt"
	cp "$TEMPOUTPUTFILE_MERGEDTVOS" "/tmp/Current-$DATECODEFORFILE.MosyleTVosDump.txt"
else
	cli_log "No Existing Dump. No BKUP created."
fi

THECOUNT=0
DataRequestFailedCount=0

# Get Bearer Token
GetBearerToken

# Sanitize token
AuthToken="${AuthToken//$'\r'/}"
AuthToken="${AuthToken//$'\n'/}"
AuthToken="${AuthToken//[[:space:]]/}"
AuthToken="${AuthToken#Bearer}"

# Temp output for this run
WORKFILE="/tmp/DUMPINPROGRESS-$DATECODEFORFILE.MosyletvOSDump.txt"
rm -f "$WORKFILE"

while true; do
	let "THECOUNT=$THECOUNT+1"
	THEPAGE="$THECOUNT"

	if [ "$DataRequestFailedCount" -gt 5 ]; then
		cli_log "TOO MANY DATA REQUEST FAILURES. ABORT!!!!!"
		exit 1
	fi

	cli_log "tvOS CLIENTS-> Asking MDM for Page $THEPAGE data...."

	curl --location 'https://managerapi.mosyle.com/v2/listdevices' \
		--header 'Content-Type: application/json' \
		--header "Authorization: Bearer $AuthToken" \
		--data "$(Generate_JSON_TVOSDUMPPostData)" \
		-o "/tmp/MOSBasicRAW-tvOS-Page$THEPAGE.txt"

	# Legacy "no devices" string
	LASTPAGE=$(cat "/tmp/MOSBasicRAW-tvOS-Page$THEPAGE.txt" | grep DEVICES_NOTFOUND)
	if [ -n "$LASTPAGE" ]; then
		let "THECOUNT=$THECOUNT-1"
		cli_log "tvOS CLIENTS-> End of list (Last good page was $THECOUNT)"
		break
	fi

	# Empty response
	if [ ! -s "/tmp/MOSBasicRAW-tvOS-Page$THEPAGE.txt" ]; then
		cli_log "Page $THEPAGE requested from Mosyle but had no data. Skipping."
		let "DataRequestFailedCount=$DataRequestFailedCount+1"
		continue
	fi

	# Token/access errors
	if grep -qi 'accessToken Required' "/tmp/MOSBasicRAW-tvOS-Page$THEPAGE.txt"; then
		let "THECOUNT=$THECOUNT-1"
		cli_log "tvOS CLIENTS-> AccessToken error..."
		break
	fi

	if grep -qi 'Unauthorized' "/tmp/MOSBasicRAW-tvOS-Page$THEPAGE.txt"; then
		cli_log "tvOS CLIENTS-> Authorization error pulling page #$THEPAGE"
		let "DataRequestFailedCount=$DataRequestFailedCount+1"
		continue
	fi

	# Normalize JSON
	Normalize_Mosyle_Devices_JSON \
		"/tmp/MOSBasicRAW-tvOS-Page$THEPAGE.txt" \
		"/tmp/MOSBasicRAW-tvOS-Page$THEPAGE.norm.json"

	if [ $? -ne 0 ]; then
		cli_log "tvOS CLIENTS-> Page $THEPAGE returned non-JSON (or malformed). Skipping."
		let "DataRequestFailedCount=$DataRequestFailedCount+1"
		continue
	fi

	# Option A: last page detection (status OK + devices [])
	if IsLastDevicesPage "/tmp/MOSBasicRAW-tvOS-Page$THEPAGE.norm.json"; then
		let "THECOUNT=$THECOUNT-1"
		cli_log "tvOS CLIENTS-> End of list (Last good page was $THECOUNT)"
		break
	fi

	# Ensure devices key exists before json2csv
	if ! grep -q '"devices"' "/tmp/MOSBasicRAW-tvOS-Page$THEPAGE.norm.json"; then
		cli_log "tvOS CLIENTS-> Page $THEPAGE missing devices key — skipping"
		let "DataRequestFailedCount=$DataRequestFailedCount+1"
		continue
	fi

	cli_log "tvOS CLIENTS-> Processing page #$THEPAGE"

	# Convert to CSV
	$PYTHON2USE \
		"$BAGCLI_WORKDIR/modules/json2csv.py" \
		devices \
		"/tmp/MOSBasicRAW-tvOS-Page$THEPAGE.norm.json" \
		"$WORKFILE"

	# Safety max pages
	if [ "$THECOUNT" -gt "$MAXPAGECOUNT" ]; then
		cli_log "tvOS CLIENTS-> Hit $THECOUNT pages... greater than max ($MAXPAGECOUNT). Something is wrong."
		break
	fi
done

# Swap output into place (keeping your behavior)
rm -Rf "$TEMPOUTPUTFILE_MERGEDTVOS"
cp "$WORKFILE" "$TEMPOUTPUTFILE_MERGEDTVOS"

if [ ! "$MB_DEBUG" = "Y" ]; then
	rm -f /tmp/MOSBasicRAW-tvOS-*.txt
	rm -f /tmp/MOSBasicRAW-tvOS-*.norm.json
else
	cli_log "tvOS CLIENTS-> DEBUG IS ENABLED. NOT CLEANING UP REMAINING FILES!!!!"
fi