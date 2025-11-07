#!/bin/sh

############################
#           Logs           #
############################
RED(){ echo -e "\033[31m\033[01m$1\033[0m";}
GREEN(){ echo -e "\033[32m\033[01m$1\033[0m";}
YELLOW(){ echo -e "\033[33m\033[01m$1\033[0m";}
BLUE(){ echo -e "\033[36m\033[01m$1\033[0m";}
WHITE(){ echo -e "\033[37m\033[01m$1\033[0m";}
BBLUE(){ echo -e "\033[34m\033[01m$1\033[0m";}
RRED(){ echo -e "\033[35m\033[01m$1\033[0m";}

LOG_LEVEL=${LOG_LEVEL:-2}
[ -z "$EXEC" ] && {
	EXEC=`basename $0 2>/dev/null`
	#export EXEC
}

verbose(){
	LOG_LEVEL=$((LOG_LEVEL+1))
}
_LOG(){
	[ "$LOG2LOGGER" = "1" ] && logger -s "${EXEC}: $@"
}

DBG(){
	[ $LOG_LEVEL -ge 5 ] && WHITE "${EXEC}: $@"
	return 0
}

LOG(){
	[ $LOG_LEVEL -ge 4 ] && {
		WHITE "${EXEC}: $@"
#		_LOG "$@"
	}
	return 0
}
INF(){
	[ $LOG_LEVEL -ge 3 ] && {
		GREEN "${EXEC}: $@"
		_LOG "$@"
	}
	return 0
}
WRN(){
	[ $LOG_LEVEL -ge 2 ] && {
		YELLOW "${EXEC}: $@"
		_LOG "$@"
	}
	return 0
}

ERR(){
	[ $LOG_LEVEL -ge 1 ] && {
		RED "${EXEC}: $@"
		_LOG "$@"
	}
	exit 1
}
############################
#       String process     #
############################
# get_prefix xxx://aaa.bbb.ccc
# print: xxx
get_prefix(){
	echo "$1" | sed '/:\/\//!d;s/:\/\/.*//'
}
# drop_prefix xxx://aaa.bbb.ccc
# print: aaa.bbb.ccc
drop_prefix(){
	echo "$1" | sed '/:\/\//!d;s/.*:\/\///'
}
# filename_prefix aa/bb/cc.dd
# print: cc
filename_prefix(){
	basename $1 | sed 's/\(.*\)\..*/\1/'
}

# Extracting MAC address from string
get_mac(){
	#echo "$@" | sed -nE 's/.*(([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}).*/\1/p'
	echo "$@" | grep -oE '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}'
}
# Extracting IP address from string
get_ip(){
	echo "$@" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}'
}
############################
#       Aarray process     #
############################
# array_init array_name
array_init(){
	eval "$1=()"
}
# array_add array_name item
array_add(){
	eval "$1+=($2)"
}
# array_remove array_name index
array_remove(){
	eval "unset $1[$2]"
}
#array_get array_name index
array_get(){
	eval "echo $1[#2]"
}
#array_flush array_name
array_flush(){
	eval "$1=()"
}
############################
#        Variables         #
############################
# check_variables aa bb cc
# return: 0: all variables exist
#         others: check fail
check_variables(){
	local val
	local chk
	[ "$#" -eq 0 ] && ERR "No params"
	for chk in $@;do
		eval val="\${$chk}"
		[ -z "$val" ] && {
			WRN "Key \"$chk\" not defined"
			return 1
		}
	done
	return 0
}
############################
#        Filesystem        #
############################
# check_files: file1 file2 ... fileN
# return: 0: all files exist
#         others: check fail
check_files(){
	local chk
	[ "$#" -eq 0 ] && ERR "No params"
	for chk in $@;do
		[ -f "$chk" ] || {
			WRN "File \"$chk\" not exist"
			return 1
		}
	done
	return 0
}
# check_file_size file min_size max_size
# return: 0: file size in range (min_size, max_size)
#         others: check fail
check_file_size(){
	local size
	local min=${2:-0}
	local max=${3:-0}
	check_files $1 || return 1
	size=`wc -c $1 | awk '{print $1}'`
	[ "$size" -lt "$min" -o "$size" -gt "$max" ] && {
		WRN "File size outof range[$min, $max]: $size"
		return 1
	}
	return 0
}
# check_dirs dir1 dir2 ... dirN
# return: 0: all dirs exist
#         others: check fail
check_dirs(){
	local chk
	[ "$#" -eq 0 ] && ERR "No params"
	for chk in $@;do
		[ -d "$chk" ] || {
			WRN "Dir \"$chk\" not exist"
			return 1
		}
	done
	return 0
}
# check_execs exec1 exec2 ... execN
# return: 0: all executable exist
#         others: check fail
check_execs(){
	local file
	local chk
	[ "$#" -eq 0 ] && ERR "No params"
	for chk in $@;do
		file=`which $chk`
		[ -z "$file" ] && {
			WRN "Package \"$chk\" not installed"
			return 1
		}
	done
	return 0
}
############################
#         Processes        #
############################
# run command in background and save pid to array 
# run_child array_name cmd param1 param2 ... paramN
# return: 0: success
#         others: fail
run_child(){
	local ret
	local array_name=$1
	shift 1
	$@ &
	ret=$?
	array_add array_name $!
	return $ret
}
# wait all child process end
# wait_childs pid1 pid2 ... pidN
# return: 0: all child process exit with success
#         others: not all child process success
wait_childs(){
	local children="$@"
	local EXIT=0
	for job in ${children[@]}; do
		CODE=0;
		wait ${job} || CODE=$?
		LOG "PID ${job} exit code: $CODE"
		[ "${CODE}" != "0" ] && EXIT=1
	done
	return $EXIT
}
############################
#           JSON           #
############################
# Convert json to variables and set them as environment variable
#json2variables json
json2variables(){
	local String
	local data
	String=`echo $@ | sed 's/": *"/="/g;s/, *"/ /g;s/^{ *"//;s/}$//'`
	for data in $String;do
		eval "$data"
	done
}
# Convert environment variables to json
# variables2json variable1 variable2 ... variableN
# print: json
variables2json(){
	local json=""
	for name in $@;do
		json="${json},\"$name\":\"${!name}\""
	done
	echo "{${json}}" | sed 's/^{,/{/'
	return 0
}
# json_get_value json key
# print: value of key
json_get_value(){
	echo "$1" | jq ".$2" | sed 's/^null$//;s/^"//;s/"$//'
}
############################
#        Algorithms        #
############################
# base64_decode base64
# print: decode result
base64_decode(){
	local len
	local str
	local atta
	local remainder
	[ -z "$1" ] && return 1
	str=`echo "$1" | sed 's/_/\//g;s/-/+/g'`
	len=${#str}
	remainder=$((len%4))
	[ "$remainder" = 3 ] && atta="="
	[ "$remainder" = 2 ] && atta="=="
	echo -n "${str}${atta}" | base64 -d 2>/dev/null
}
############################
#        Internet          #
############################
# download URL DIST_FILE
# return: 0: success
#         others: fail
download(){
	local QUIET="-q "
	DBG "Download from $1 to $2"
	[ $LOG_LEVEL -ge 4 ] && QUIET=""
	wget $QUIET $1 -O $2
}

############################
#           APPs           #
############################
_rsync_version(){
	[ -z "$1" ] && {
		rsync --version | sed '/rsync *version/!d;s/.*version \([0-9]\)\.\([0-9]\).*/\1\2/'
		return
	}
	ssh -n $1 'rsync --version 2>/dev/null' | sed '/rsync *version/!d;s/.*version \([0-9]\)\.\([0-9]\).*/\1\2/'
}
rsync_params(){
#	local version
	local _base="-H -a -p"
#	version=`_rsync_version`
#	[ -z "$version" ] && return 1
#	[ "$LOG_LEVEL" -ge "5" ] && _base="-v $_base" || _base="-q $_base"
#	[ "$version" -ge 32 ] && {
#		#echo -n "--open-noatime "
#		#echo "$_base -A $@"
#		echo "$_base $@"
#		return 0
#	}
#	[ "$version" -ge 31 ] && {
#		#echo -n "--noatime "
#		#echo "$_base -A $@"
#		echo "$_base $@"
#		return 0
#	}
#	#unmatch version, 'atime' is not supported
	echo "$_base $@"
	return 0;
}
############################
#            OS            #
############################
os_name(){
	local _OS
	_OS:=$(uname)
	[ "$_OS" == "Linux" ] && {
		_OS:=$(uname -o | sed 's/.*\///')
	}
	echo "$_OS"
}
node_name(){
	local _NODE
	_NODE:=$(uname -n)
	[ "$_NODE" == "localhost" ] && {
		if [ -n "$HOSTNAME" ]
		then
			_NODE=$HOSTNAME
		else
			_NODE:=$(getprop net.hostname 2>/dev/null)
		fi
	}
	echo "$_NODE"
}

