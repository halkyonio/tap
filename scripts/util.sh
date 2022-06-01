
#display_usage() {
#	echo "Execute this script ./create_tce_cluster.sh"
#	echo -e "\nUsage: $0 [arguments] \n"
#}

## if less than two arguments supplied, display usage
#if [  $# -le 1 ]
#then
#	display_usage
#	exit 1
#fi

# Defining some colors for output
RED='\033[0;31m'
NC='\033[0m' # No Color
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'

repeat_char(){
  COLOR=${1}
	for i in {1..50}; do echo -ne "${!COLOR}$2${NC}"; done
}

log_line() {
    COLOR=${1}
    MSG="${@:2}"
    echo -e "${!COLOR}## ${MSG}${NC}"
}

log_msg() {
    COLOR=${1}
    MSG="${@:2}"
    echo -e "\n${!COLOR}## ${MSG}${NC}"
}

log() {
  MSG="${@:2}"
  echo; repeat_char ${1} '#'; log_msg ${1} ${MSG}; repeat_char ${1} '#'; echo
}

repeat(){
	local start=1
	local end=${1:-80}
	local str="${2:-=}"
	local range=$(seq $start $end)
	for i in $range ; do echo -n "${str}"; done
}