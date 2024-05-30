#!/bin/sh -euf

set -euf

help_msg="
	usage: mk-epair [-h] [-u <num>] [-n/N <name>] [-e/E <mac>] [-m/M <bridge>] [-g/G <group>] [-i/I <args>]

	As the name suggests epair interfaces come in pairs.
	The pairs start out named epair\${N}a and epair\${N}b.

	This script attempts to create and configure a pair of epair interfaces.

	On success it prints the names of both interfaces on a single line
	to standard output separated by a space and exits with status 0.
	
	On failure it attempts to undo any changes it made
	and exists with a status != 0.

		-h          : Print this help and exit.
		-v          : Print verbose progress messages to standard error.
		-u <num>    : Create epair a specific unit number. (optional, single-use)
		-n <name>   : Rename interface epair\${N}a. (optional, single-use)
		-N <name>   : Rename interface epair\${N}b. (optional, single-use)
		-e <mac>    : Set the MAC address of interface epair\${N}a. (optional, single-use)
		-E <mac>    : Set the MAC address of interface epair\${N}b. (optional, single-use)
		-j <jail>   : Move epair\${N}a over into a vnet enabled jail. (optional, single-use)
		-J <jail>   : Move epair\${N}b over into a vnet enabled jail. (optional, single-use)
		-m <bridge> : Add epair\${N}a as member to an existing bridge. (optional, single-use)
		-M <bridge> : Add epair\${N}b as member to an existing bridge. (optional, single-use)
		-g <group>  : Add epair\${N}a to an interface group. (optional, multi-use)
		-G <group>  : Add epair\${N}b to an interface group. (optional, multi-use)
		-i <args>   : Run custom ifconfig invocation on epair\${N}a. Use with care. (optional, multi-use)
		-I <args>   : Run custom ifconfig invocation on epair\${N}b. Use with care. (optional, multi-use)"

help() {
	echo "$help_msg"
	exit 0
}

usage() {
	printf '\tusage error: %s\n\n%s\n' "$*" "$help_msg" >&2
	exit 64
}

verbose='no'
unit=''
name_a=''
name_b=''
rename_a=''
rename_b=''
mac_a=''
mac_b=''
jail_a=''
jail_b=''
bridge_a=''
bridge_b=''
groups_a=''
groups_b=''
ifconf_a=''
ifconf_b=''

set_verbose() {
	verbose='yes'
}

log() {
	if [ "$verbose" = 'yes' ]; then
		printf "mk-epair: %s\n" "$*" >&2
	fi
	logger -t "mk-epair" -- "$*"
}

fail() {
	set_verbose
	log "$@"
	exit 1
}

set_unit() {
	if [ -n "$unit" ]; then
		usage '-i <num> can only be used once.'
	fi
	case "$1" in
		-*)
			usage 'unit number must be >= 0'
			;;

		0[0-9]*)
			usage 'unit number must be given without leading zeros'
			;;

		*[!0-9]*)
			usage 'unit number be a decimal number >= 0'
			;;

		'')	usage 'if specified the number number must not be empty'
			;;

		?*)
			unit="$1"
			;;
	esac
}

set_rename() {
	local flag="$1" var="$2" old="$3" new="$4"
	if [ -n "$old" ]; then
		usage "-$flag <name> : can only be used once."
	fi
	case "$new" in
		'')
			usage "-$flag <name> : name too short : allowed length is 1-15 bytes"
			;;

		????????????????*)
			usage "-$flag <name> : name too long : allowed length is 1-15 bytes"
			;;

		*[$'\t']*)
			usage "-$flag <name> : refusing name containing TAB"
			;;

		*[$'\n']*)
			usage "-$flag <name> : refusing name containing NEWLINE"
			;;

		*[' ']*)
			usage "-$flag <name> : refusing name containing SPACE"
			;;
	esac
	case " $(ifconfig -l) " in
		*" $new "*)
			usage "-$flag <name> : name is already taken"
			;;
	esac
	setvar "$var" "$new"
}

set_mac() {
	local flag="$1" var="$2" old="$3" new="$4"
	if [ -n "$old" ]; then
		usage "-$flag <mac> : can only be used once."
	fi
	case "$new" in
		[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f])
			;;

		*)
			usage "-$flag <mac> : must be formatted as xx:xx:xx:xx:xx:xx using only lower-case hex digits"
			;;
	esac
	setvar "$var" "$new"
}

set_jail() {
	local flag="$1" var="$2" old="$3" new="$4"
	if [ -n "$old" ]; then
		usage "-$flag <jail> : can only be used once."
	fi
	if [ -z "$new" ]; then
		usage "-$flag <jail> : jail name must not be empty."
	fi
	setvar "$var" "$new"
}

set_bridge() {
	local flag="$1" var="$2" old="$3" new="$4"
	if [ -n "$old" ]; then
		usage "-$flag <bridge> : can only be used once."
	fi
	case "$new" in
		'')
			usage "-$flag <bridge> : bridge name too short : allowed length is 1-15 bytes"
			;;

		????????????????*)
			usage "-$flag <bridge> : bridge name too long : allowed length is 1-15 bytes"
			;;

		*[$'\t']*)
			usage "-$flag <bridge> : refusing bridge name containing TAB"
			;;

		*[$'\n']*)
			usage "-$flag <bridge> : refusing bridge name containing NEWLINE"
			;;

		*[' ']*)
			usage "-$flag <bridge> : refusing bridge name containing SPACE"
			;;
	esac
	case " $(ifconfig -l -g bridge) " in
		*" $new "*)
			;;

		*)
			usage "-$flag <bridge> : bridge does not exist"
			;;
	esac
	setvar "$var" "$new"
}

add_groups() {
	local flag="$1" var="$2" old="$3" new="$4"
	case "$new" in
		'')
			usage "-$flag <group> : group name too short : allowed length is 1-15 bytes"
			;;

		????????????????*)
			usage "-$flag <group> : group name too long : allowed length is 1-15 bytes"
			;;

		*[0-9])
			usage "-$flag <group> : group name must not end with a decimal digit"
			;;

		*[$'\t']*)
			usage "-$flag <group> : refusing group name containing TAB"
			;;

		*[$'\n']*)
			usage "-$flag <group> : refusing group name containing NEWLINE"
			;;

		*[' ']*)
			usage "-$flag <group> : refusing group name containing SPACE"
			;;
	esac
	case " $old " in
		*" $new "*)
			echo "warning: -$flag $new repeated" >&2
			;;
	esac
	setvar "$var" "$old $new"
}

add_ifconf() {
	local flag="$1" var="$2" old="$3" new="$4"
	if [ -z "$new" ]; then
		usage "-$flag <args> : refusing empty custom ifconfig invocation"
	fi
	setvar "$var" "$old$new"$'\n'
}

set_rename_a() {
	local new="$1"
	set_rename 'n' rename_a "$rename_a" "$new"
}

set_rename_b() {
	local new="$1"
	set_rename 'N' rename_b "$rename_b" "$new"
}

set_mac_a() {
	local new="$1"
	set_mac 'e' mac_a "$mac_a" "$new"
}

set_mac_b() {
	local new="$1"
	set_mac 'E' mac_b "$mac_b" "$new"
}

set_jail_a() {
	local new="$1"
	set_jail 'j' jail_a "$jail_a" "$new"
}

set_jail_b() {
	local new="$1"
	set_jail 'J' jail_b "$jail_b" "$new"
}

set_bridge_a() {
	local new="$1"
	set_bridge 'm' bridge_a "$bridge_a" "$new"
}

set_bridge_b() {
	local new="$1"
	set_bridge 'M' bridge_b "$bridge_b" "$new"
}

add_groups_a() {
	local new="$1"
	add_groups 'g' groups_a "$groups_a" "$new"
}

add_groups_b() {
	local new="$1"
	add_groups 'G' groups_b "$groups_b" "$new"
}

add_ifconf_a() {
	local new="$1"
	add_ifconf 'i' ifconf_a "$ifconf_a" "$new"
}

add_ifconf_b() {
	local new="$1"
	add_ifconf 'I' ifconf_b "$ifconf_b" "$new"
}

create_epair() {
	if [ -n "$unit" ]; then
		if ! name_a="$(ifconfig -- "epair${unit}" create)"; then
			fail "Failed to create interface pair epair${unit}a + epair${unit}b."
		fi
	else
		if ! name_a="$(ifconfig -- epair create)"; then
			fail "Failed to create a new epair interface pair."
		fi
	fi
	name_b="${name_a%a}b"
	log "Created epair interface pair $name_a + $name_b."
}

rename() {
	local var="$1" old="$2" new="$3"
	if [ -n "$new" ] && [ "$new" != "$old" ]; then
		log "Rename epair interface from $old to $new."
		if ifconfig "$old" name "$new" >/dev/null; then
			setvar "$var" "$new"
		else
			fail "Failed to rename epair interface from $old to $new."
		fi
	fi
}

change_mac() {
	local name="$1" mac="$2"
	if [ -n "$mac" ]; then
		log "Set epair interface $name MAC address to $mac."
		if ! ifconfig -n -- "$name" ether "$mac"; then
			fail "Failed to change epair interface $name MAC address to $mac."
		fi
	fi
}

move_vnet() {
	local name="$1" jail="$2"
	if [ -n "$jail" ]; then
		log "Move epair interface $name to vnet enabled jail $jail."
		if ! ifconfig -n -- "$name" vnet "$jail"; then
			fail "Failed to move epair interface $name to vnet enabled jail $jail."
		fi
	fi
}

add_member() {
	local name="$1" bridge="$2" jail="$3"
	if [ -n "$bridge" ]; then
		log "Add interface $name as member to bridge interface $bridge."
		set -- ifconfig -n
		if [ -n "$jail" ]; then
			set -- "$@" -j "$jail"
		fi
		set -- "$@" -- "$bridge" addm "$name"
		if ! "$@"; then
			fail "Failed to add interface $name as member to bridge interface $bridge."
		fi
	fi
}

join_groups() {
	local name="$1" jail="$2" group; shift 2
	if [ $# -gt 0 ]; then
		log "Add interface $name to groups: $*."
		for group; do
			set -- ifconfig -n
			if [ -n "$jail" ]; then
				set -- "$@" -j "$jail"
			fi
			set -- "$@" -- "$name" group "$group"
			if ! "$@"; then
				fail "Failed to add interface $name to group $group."
			fi
		done
	fi
}

invoke_ifconfig() {
	local name="$1" jail="$2" args="$3" IFS=$'\n'; shift 3
	for arg in $args; do
		IFS=$' \t\n'
		set -- ifconfig -n
		if [ -n "$jail" ]; then
			set -- "$@" -j "$jail"
		fi
		set -- "$@" -- "$name" $arg
		log "Invoke custom ifconfig: $*" 
		if ! "$@"; then
			fail "Custom ifconfig failed: $*"
		fi
	done
}

rename_epair() {
	rename name_a "$name_a" "$rename_a"
	rename name_b "$name_b" "$rename_b"
}

mac_epair() {
	change_mac "$name_a" "$mac_a"
	change_mac "$name_b" "$mac_b"
}

vnet_epair() {
	move_vnet "$name_a" "$jail_a"
	move_vnet "$name_b" "$jail_b"
}

bridge_epair() {
	add_member "$name_a" "$bridge_a" "$jail_a"
	add_member "$name_b" "$bridge_b" "$jail_b"
}

groups_epair() {
	join_groups "$name_a" "$jail_a" $groups_a
	join_groups "$name_b" "$jail_b" $groups_b
}

ifconf_epair() {
	invoke_ifconfig "$name_a" "$jail_a" "$ifconf_a"
	invoke_ifconfig "$name_b" "$jail_b" "$ifconf_b"
}

cleanup() {
	log "Failed with exit status = $?."
	if [ -n "$name_a" ]; then
		ifconfig -n -- "$name_a" destroy
	fi
}


main() {
	while getopts hvu:n:N:e:E:j:J:m:M:g:G:i:I: arg
	do
		case "$arg" in
			h) help                      ;;
			v) set_verbose               ;;
			u) set_unit     "$OPTARG"    ;;
			n) set_rename_a "$OPTARG"    ;;
			N) set_rename_b "$OPTARG"    ;;
			e) set_mac_a    "$OPTARG"    ;;
			E) set_mac_b    "$OPTARG"    ;;
			j) set_jail_a   "$OPTARG"    ;;
			J) set_jail_b   "$OPTARG"    ;;
			m) set_bridge_a "$OPTARG"    ;;
			M) set_bridge_b "$OPTARG"    ;;
			g) add_groups_a "$OPTARG"    ;;
			G) add_groups_b "$OPTARG"    ;;
			i) add_ifconf_a "$OPTARG"    ;;
			I) add_ifconf_b "$OPTARG"    ;;
			*) usage 'invalid arguments' ;;
		esac
	done

	trap cleanup EXIT INT TERM

	create_epair
	rename_epair
	mac_epair
	vnet_epair
	bridge_epair
	groups_epair
	ifconf_epair

	printf "%s %s\n" "$name_a" "$name_b"

	trap - EXIT
}

main "$@"