#!/bin/zsh

################################################################
#
#	userdump.sh
#		Script pulls users from Mosyle and sorts them out
#		into a single file.
#
#		JCS - 9/28/2021  -v1
#   PATCHED - 02/04/2026
#
#   Fixes:
#   - Handles wrapped vs unwrapped Mosyle JSON responses
#   - Removes cut/sed JSON corruption
#   - Strips trailing '%' seen in Mosyle output
#   - Prevents json2csv KeyError crashes
#   - Option A: Detect last page when status==OK and users==[]
#
################################################################

source "$BAGCLI_WORKDIR/config"
source "$BAGCLI_WORKDIR/common"
IFS=$'\n'

CMDRAN="userdump"

#################################
#            Functions          #
#################################

Generate_JSON_UserDUMPPostData() {
cat <<EOF
{
  "accessToken": "$MOSYLE_API_key",
  "options": {
    "page": "$THEPAGE",
    "specific_columns": [ "id", "name", "managedappleid", "type" ],
    "page_size": "$NumberOfReturnsPerPage"
  }
}
EOF
}

# Normalize Mosyle JSON so json2csv always sees top-level "users"
Normalize_Mosyle_Users_JSON() {
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
    # Preserve whatever we got for debugging
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

# Option A: JSON-accurate last-page detection
# Return code 0 => YES, this is the end (status OK, users empty list)
IsLastUsersPage() {
  local FILE="$1"
  python3 - "$FILE" <<'PY'
import json, sys
p=sys.argv[1]
raw=open(p,"r",encoding="utf-8",errors="replace").read().strip()

# If something somehow reintroduces a trailing '%'
if raw.endswith('%'):
    raw = raw[:-1].rstrip()

d=json.loads(raw)

users = d.get("users", None)
status = d.get("status", "")

if status == "OK" and isinstance(users, list) and len(users) == 0:
    sys.exit(0)
sys.exit(1)
PY
}

################################
#            DO WORK           #
################################

rm -Rf "$TEMPOUTPUTFILE_Users"

THECOUNT=0
DataRequestFailedCount=0

# Fetch Bearer token
GetBearerToken

# Sanitize token
AuthToken="${AuthToken//$'\r'/}"
AuthToken="${AuthToken//$'\n'/}"
AuthToken="${AuthToken//[[:space:]]/}"
AuthToken="${AuthToken#Bearer}"

while true; do
	let "THECOUNT=$THECOUNT+1"
	THEPAGE="$THECOUNT"

	if [ "$DataRequestFailedCount" -gt 5 ]; then
		cli_log "TOO MANY DATA REQUEST FAILURES. ABORTING."
		exit 1
	fi

	cli_log "MOSYLE USERS-> Asking MDM for Page $THEPAGE data...."

	curl --location 'https://managerapi.mosyle.com/v2/listusers' \
		--header 'Content-Type: application/json' \
		--header "Authorization: Bearer $AuthToken" \
		--data "$(Generate_JSON_UserDUMPPostData)" \
		-o "/tmp/MOSBasicRAW-Users-Page$THEPAGE.txt"

	# Empty file check
	if [ ! -s "/tmp/MOSBasicRAW-Users-Page$THEPAGE.txt" ]; then
		cli_log "MOSYLE USERS-> Empty response for page $THEPAGE"
		let "DataRequestFailedCount=$DataRequestFailedCount+1"
		continue
	fi

	# Normalize JSON
	Normalize_Mosyle_Users_JSON \
		"/tmp/MOSBasicRAW-Users-Page$THEPAGE.txt" \
		"/tmp/MOSBasicRAW-Users-Page$THEPAGE.norm.json"

	# If normalization failed (not JSON), skip and retry
	if [ $? -ne 0 ]; then
		cli_log "MOSYLE USERS-> Page $THEPAGE returned non-JSON (or malformed). Skipping."
		let "DataRequestFailedCount=$DataRequestFailedCount+1"
		continue
	fi

	# Option A: End-of-list detection (status OK + users [])
	if IsLastUsersPage "/tmp/MOSBasicRAW-Users-Page$THEPAGE.norm.json"; then
		let "THECOUNT=$THECOUNT-1"
		cli_log "MOSYLE USERS-> End of list (Last good page was $THECOUNT)"
		break
	fi

	# Validate presence of users key (protect json2csv)
	if ! grep -q '"users"' "/tmp/MOSBasicRAW-Users-Page$THEPAGE.norm.json"; then
		cli_log "MOSYLE USERS-> Page $THEPAGE missing users key — skipping"
		let "DataRequestFailedCount=$DataRequestFailedCount+1"
		continue
	fi

	# Convert to CSV
	$PYTHON2USE \
		"$BAGCLI_WORKDIR/modules/json2csv.py" \
		users \
		"/tmp/MOSBasicRAW-Users-Page$THEPAGE.norm.json" \
		"$TEMPOUTPUTFILE_Users"

	if [ "$THECOUNT" -gt "$MAXPAGECOUNT" ]; then
		cli_log "MOSYLE USERS-> Hit max page count ($MAXPAGECOUNT). Aborting."
		break
	fi
done

if [ ! "$MB_DEBUG" = "Y" ]; then
	rm -f /tmp/MOSBasicRAW-Users-*.txt
	rm -f /tmp/MOSBasicRAW-Users-*.norm.json
else
	cli_log "MOSYLE USERS-> DEBUG ENABLED — temp files preserved"
fi