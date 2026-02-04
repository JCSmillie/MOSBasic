#!/bin/zsh

################################################################
#
#	mosdatadump-CLASSES.sh
#		Script to query Mosyle and return a list of class names and the student usernames
#		into a single file.
#
#		JCS - 9/2/2025
#   PATCHED - 02/04/2026
#
#   Fixes:
#   - Normalize wrapped/unwrapped Mosyle JSON (unwrap response)
#   - Strip trailing '%' if present
#   - Option A last page detection: status==OK and classes==[]
#   - Make jq processing operate on normalized JSON (.classes)
#   - Sanitize bearer token once (don’t re-login every page)
#
################################################################

source "$BAGCLI_WORKDIR/config"
source "$BAGCLI_WORKDIR/common"
IFS=$'\n'

CMDRAN="classdump"

if [ "$MB_DEBUG" = "Y" ]; then
	echo "Variable 1-> $1"
	echo "Variable 2-> $2"
	echo "Variable 3-> $3"
	echo "Variable 4-> $4"
fi

#Classes - EDUONLY
TEMPOUTPUTFILE_MERGEDClasses="/tmp/Mosyle_active_Classes_MergedClasses.txt"

# MOSBasic scripts are used here and relied on
BAGCLI_WORKDIR=$(readlink /usr/local/bin/mosbasic)
BAGCLI_WORKDIR=${BAGCLI_WORKDIR/mosbasic/}
export BAGCLI_WORKDIR

source "$BAGCLI_WORKDIR/config"
. "$BAGCLI_WORKDIR/common"
LOG=/dev/null

#################################
#            Functions          #
#################################

log_line() {
	echo "$1"
}

#According to documentation available 9/2/25 these are the possible columns.
# id, class_name, course_name, location, teacher, students, coordinators, account
# I'm not querying course_name or account currently -JCS
Generate_JSON_ClassDUMPPostData() {
cat <<EOF
{
  "accessToken": "$MOSYLE_API_key",
  "options": {
    "page": "$THEPAGE",
    "specific_columns": ["id","class_name","location","teacher","students","coordinators"],
    "page_size": "$NumberOfReturnsPerPage"
  }
}
EOF
}

# Normalize Mosyle JSON so downstream code sees top-level "classes"
# - unwraps {"status":"OK","response":{...}} into { ... }
# - strips trailing '%'
Normalize_Mosyle_Classes_JSON() {
  local INFILE="$1"
  local OUTFILE="$2"

  python3 - "$INFILE" "$OUTFILE" <<'PY'
import json, sys

inp, outp = sys.argv[1], sys.argv[2]
raw = open(inp, "r", encoding="utf-8", errors="replace").read().strip()

if raw.endswith('%'):
    raw = raw[:-1].rstrip()

try:
    d = json.loads(raw)
except Exception:
    with open(outp, "w", encoding="utf-8") as f:
        f.write(raw + "\n")
    sys.exit(2)

# unwrap response if present
if isinstance(d, dict) and isinstance(d.get("response"), dict):
    d = d["response"]

with open(outp, "w", encoding="utf-8") as f:
    json.dump(d, f)
    f.write("\n")
PY
}

# Option A: last-page detection for classes
# Return code 0 => YES last page (status OK + classes empty list)
IsLastClassesPage() {
  local FILE="$1"
  python3 - "$FILE" <<'PY'
import json, sys
p=sys.argv[1]
raw=open(p,"r",encoding="utf-8",errors="replace").read().strip()
if raw.endswith('%'):
    raw = raw[:-1].rstrip()

d=json.loads(raw)
classes = d.get("classes", None)
status  = d.get("status", "")

if status == "OK" and isinstance(classes, list) and len(classes) == 0:
    sys.exit(0)
sys.exit(1)
PY
}

GetClassData() {
	# This function writes the raw page response to a file and leaves it for the caller to normalize/parse.
	curl -s --location 'https://managerapi.mosyle.com/v2/listclasses' \
		--header 'content-type: application/json' \
		--header "Authorization: Bearer $AuthToken" \
		--data "$(Generate_JSON_ClassDUMPPostData)" \
		-o "/tmp/MOSBasicRAW-ClassDump-Page$THEPAGE.txt"
}

# Process normalized JSON to csv but using ";" as separator.
# Expects normalized JSON with top-level "classes"
convert_mosyle_json_to_csv_inline() {
  jq -r '
    if (.classes != null and (.classes | type == "array")) then
      .classes[] |
      [
        .id,
        .class_name,
        .location,
        (.teacher // [] | join(",")),
        (.students // [] | join(",")),
        (.coordinators // [] | join(","))
      ] |
      @csv
    else
      empty
    end
  ' 2>/dev/null |
  sed 's/","/;/g; s/^"//; s/"$//'
}

################################
#            DO WORK           #
################################

rm -Rf /tmp/Mosyle_active_Classes.txt

THECOUNT=0
DataRequestFailedCount=0

# Get bearer token ONCE
GetBearerToken

# Sanitize token
AuthToken="${AuthToken//$'\r'/}"
AuthToken="${AuthToken//$'\n'/}"
AuthToken="${AuthToken//[[:space:]]/}"
AuthToken="${AuthToken#Bearer}"

# Ensure header exists once
echo "ID;Class Name;Location;Teacher;Students;Coordinators" > /tmp/Mosyle_active_Classes.txt

while true; do
	let "THECOUNT=$THECOUNT+1"
	THEPAGE="$THECOUNT"

	if [ "$DataRequestFailedCount" -gt 5 ]; then
		cli_log "TOO MANY DATA REQUEST FAILURES. ABORT!!!!!"
		exit 1
	fi

	cli_log "MOSYLE CLASSES-> Asking MDM for Page $THEPAGE data...."

	# Run query for this page to raw file
	GetClassData

	# Make sure output file has content
	if [ ! -s "/tmp/MOSBasicRAW-ClassDump-Page$THEPAGE.txt" ]; then
		cli_log "Page $THEPAGE requested from Mosyle but had no data. Skipping."
		let "DataRequestFailedCount=$DataRequestFailedCount+1"
		continue
	fi

	# Normalize into .norm.json
	Normalize_Mosyle_Classes_JSON \
		"/tmp/MOSBasicRAW-ClassDump-Page$THEPAGE.txt" \
		"/tmp/MOSBasicRAW-ClassDump-Page$THEPAGE.norm.json"

	if [ $? -ne 0 ]; then
		cli_log "MOSYLE CLASSES-> Page $THEPAGE returned non-JSON (or malformed). Skipping."
		let "DataRequestFailedCount=$DataRequestFailedCount+1"
		continue
	fi

	# Token failures
	if grep -qi 'accessToken Required' "/tmp/MOSBasicRAW-ClassDump-Page$THEPAGE.txt"; then
		let "THECOUNT=$THECOUNT-1"
		cli_log "MOSYLE CLASSES-> AccessToken error...(Page $THECOUNT)"
		break
	fi

	# Legacy "no classes" string (keep, but Option A is primary)
	if grep -q 'NO_CLASSES_FOUND' "/tmp/MOSBasicRAW-ClassDump-Page$THEPAGE.txt"; then
		let "THECOUNT=$THECOUNT-1"
		cli_log "MOSYLE CLASSES-> End of list (Last good page was $THECOUNT)"
		break
	fi

	# Option A: status OK + classes []
	if IsLastClassesPage "/tmp/MOSBasicRAW-ClassDump-Page$THEPAGE.norm.json"; then
		let "THECOUNT=$THECOUNT-1"
		cli_log "MOSYLE CLASSES-> End of list (Last good page was $THECOUNT)"
		break
	fi

	# Append converted rows (no header here; we wrote it once at the top)
	cat "/tmp/MOSBasicRAW-ClassDump-Page$THEPAGE.norm.json" | convert_mosyle_json_to_csv_inline >> /tmp/Mosyle_active_Classes.txt
done

if [ ! "$MB_DEBUG" = "Y" ]; then
	rm /tmp/MOSBasicRAW-ClassDump-*.txt 2>/dev/null
	rm /tmp/MOSBasicRAW-ClassDump-*.norm.json 2>/dev/null
else
	cli_log "CLASSES DUMP-> DEBUG IS ENABLED. NOT CLEANING UP REMAINING FILES!!!!"
fi

cat /tmp/Mosyle_active_Classes.txt > "$TEMPOUTPUTFILE_MERGEDClasses"