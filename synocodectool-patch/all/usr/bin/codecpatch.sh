#!/bin/ash

# https://en.wikipedia.org/wiki/Almquist_shell
# 
# 
# Adapted by Fabio Belavenuto for ARPL project
# 01/2023
# 
# Modified by SkyMaster for Fabio Belavenuto's ARPL project
# 03/2023, synocodectool-patch

set -eo pipefail;
shopt -s nullglob;

#variables

script_name="${0##*/}"
script_dir="${0%/*}"
dbg_m=0
exit_val=0

bin_file="synocodectool"
conf_file="activation.conf"
conf_path="/usr/syno/etc/codec"
conf_string='{"success":true,"activated_codec":["hevc_dec","ac3_dec","h264_dec","h264_enc","aac_dec","aac_enc","mpeg4part2_dec","vc1_dec","vc1_enc"],"token":"123456789987654abc"}'
patches_path="/tmp/patches"
opmode="patchhelp"

declare -a binpath_list=()


#functions

print_usage() { 
printf "
SYNOPSIS
    $script_name [-h] [-p|-r|-l|-d]
DESCRIPTION
    Patch to enable transcoding without a valid serial in DSM 7+
        -h      Print this help message
        -p      Patch synocodectool
        -r      Restore from original from backup
        -l      List supported DSM versions
        -d      Debug-Mode
"
}

spoofed_activation () {
    if [[ $dbg_m == 1 ]]; then
        echo "FUNCTION: ${FUNCNAME[*]}" >&2
    fi

    echo "Creating spoofed activation.conf.."

    if [[ ! -d "$conf_path" ]]; then
        mkdir -p "$conf_path"
    fi

    if [[ -f "$conf_path/$conf_file" ]]; then
       chattr -i "$conf_path/$conf_file"
    fi

    echo "$conf_string_ext" > "$conf_path/$conf_file"
    chattr +i "$conf_path/$conf_file"
    echo "Spoofed activation.conf created successfully"

    if [[ -f "$conf_path/$conf_file" ]]; then
        return 0
    fi

    return 1
}

check_version () {
    local ver="$1"
    for i in "${versions_list[@]}" ; do
        #if [[ $dbg_m == 1 ]]; then
        #    echo "FUNCTION: ${FUNCNAME[*]}" >&2
        #    echo "versions_list entry: $i"
        #fi

        if [[ "$i" == "$ver" ]]; then
            return 0
        fi
    done
    
    return 1
}

list_versions () {
    for i in "${versions_list[@]}"; do
        echo "$i"
    done

    return 0
}

patch () {
    local bin_path="$1"
    local backup_path="${bin_path%??????????????}/backup"
    local synocodectool_hash="$(sha1sum "$bin_path" | cut -f1 -d\ )"
    local activated=0

    if [[ $dbg_m == 1 ]]; then
        echo "FUNCTION: ${FUNCNAME[*]}" >&2
        echo "$bin_path hash: $synocodectool_hash"
    fi

    if [[ "${binhash_version_list[$synocodectool_hash]+isset}" ]] ; then
        local backup_identifier="${synocodectool_hash:0:8}"
        if [[ $dbg_m == 1 ]]; then
            echo "backup_identifier: $backup_identifier"
        fi
        if [[ -f "$backup_path/$bin_file.$backup_identifier" ]]; then
            backup_hash="$(sha1sum "$backup_path/$bin_file.$backup_identifier" | cut -f1 -d\ )"
            if [[ $dbg_m == 1 ]]; then
                echo "backup_hash: $backup_hash"
            fi
            if [[ "${binhash_version_list[$backup_hash]+isset}" ]]; then
                echo "Restored synocodectool and valid backup detected (DSM ${binhash_version_list[$backup_hash]}). Patching..."
                echo -e "${binhash_patch_list[$synocodectool_hash]}" | xxd -r - "$bin_path"
                ret_tmp=$?
                if [[ $dbg_m == 1 ]]; then
                    echo "xxd ret_tmp: $ret_tmp"
                fi
                echo "Patched successfully"
                spoofed_activation || ret_tmp=$?
                return $ret_tmp
            else
                echo "Corrupted backup and original synocodectool detected. Overwriting backup..."
                mkdir -p "$backup_path"
                cp -p "$bin_path" "$backup_path/$bin_file.$backup_identifier"
                return 2
            fi
        else
            echo "Detected valid synocodectool. Creating backup.."
            mkdir -p "$backup_path"
            cp -p "$bin_path" "$backup_path/$bin_file.$backup_identifier"
            echo "Patching..."
            echo -e "${binhash_patch_list[$synocodectool_hash]}" | xxd -r - "$bin_path"
            ret_tmp=$?
            if [[ $dbg_m == 1 ]]; then
                echo "xxd ret_tmp: $ret_tmp"
            fi
            echo "Patched"
            spoofed_activation || ret_tmp=$?
            return $ret_tmp
        fi
    elif [[ "${patchhash_binhash_list[$synocodectool_hash]+isset}" ]]; then
        local original_hash="${patchhash_binhash_list[$synocodectool_hash]}"
        local backup_identifier="${original_hash:0:8}"
        if [[ $dbg_m == 1 ]]; then
            echo "original_hash: $original_hash"
            echo "backup_identifier: $backup_identifier"
        fi
        if [[ -f "$backup_path/$bin_file.$backup_identifier" ]]; then
            backup_hash="$(sha1sum "$backup_path/$bin_file.$backup_identifier" | cut -f1 -d\ )"
            if [[ $dbg_m == 1 ]]; then
                echo "backup_hash: $backup_hash"
            fi
            if [[ "$original_hash"="$backup_hash" ]]; then
                echo "Valid backup and patched synocodectool detected. Skipping patch."
                return 0
            else
                echo "Patched synocodectool and corrupted backup detected. Skipping patch."
                return 1
            fi
        else
            echo "Patched synocodectool and no backup detected. Skipping patch."
            return 1
        fi
    else
        echo "Corrupted synocodectool detected. Please use the -r option to try restoring it."

        if [[ $dbg_m == 1 ]]; then
            echo "$dsm_version\n$bin_path hash sha1sum: $synocodectool_hash" >> "$script_dir/$dsm_version.txt"
        fi

        return 1
    fi
	
	return 1
}

#main

if [[ ! $EUID == 0 ]]; then
    echo "Please run as root"
    exit 1
fi

while getopts "prhld" flag; do
    case "${flag}" in
        p) opmode="patch";;
        r) opmode="patchrollback";;
        h) opmode="${opmode}"; print_usage; exit 2;;
        l) opmode="listversions";;
        d) opmode="patchdebug"; dbg_m=1; echo "debug mode: $dbg_m";;
        *) echo "Incorrect option specified in command line"; exit 2;;
    esac
done

#case "${opmode}" in
#    patch) patch ;;
#    patchrollback) rollback ;;
#    patchhelp) print_usage ; exit 2 ;;
#    listversions) list_versions ;;
#    *) echo "Incorrect combination of flags. Use option -h to get help."
#       exit 2 ;;
#esac

# Get updated patches
curl -L "https://raw.githubusercontent.com/SkyMasterROG/arpl-addons/main/synocodectool-patch/patches" -o $patches_path \
|| echo "last error: $?" > /dev/nul
if [[ ! -f "$patches_path" && $dbg_m == 0 ]]; then
    echo "Something went wrong. Could not find $patches_path"
    exit 1

elif [[ $dbg_m == 1 ]]; then
	echo "$script_name from $script_dir"
    patches_path="$script_dir/../../../patches"
    if [[ -f "$patches_path" ]]; then
		echo "patches from $patches_path"
        source $patches_path
    fi
else
    source $patches_path
fi

source "/etc/VERSION"
dsm_version="$productversion $buildnumber-$smallfixnumber"
if [[ ! "$dsm_version" ]] ; then
    echo "Something went wrong. Could not fetch DSM version"
    exit 1
fi

echo "Detected DSM version: $dsm_version"

if ! check_version "$dsm_version" ; then
    echo "Patch for DSM Version ($dsm_version) not found."
    if [[ $dbg_m == 1 ]]; then
        opmode="${opmode} version"
        echo "opmode: $opmode"
    else
        exit 1
    fi
else
	echo "Patch for DSM Version ($dsm_version) AVAILABLE!"
fi

if  ! (( ${#path_list[@]} )) ; then
    echo "Something went wrong. Could not find path_list"
    exit 1
fi

for i in "${path_list[@]}"; do
    if [ -e "$i/$bin_file" ]; then
        binpath_list+=( "$i/$bin_file" )

        if [[ $dbg_m == 1 ]]; then
            echo "added path_list entry: $i/$bin_file"
        fi
    fi
done

if  ! (( ${#binpath_list[@]} )) ; then
    echo "Something went wrong. Could not find $bin_file"
    exit 1
fi

for file in "${binpath_list[@]}"; do
    patch "${file}" || ret_tmp=$?
    
	if [[ $dbg_m == 1 ]]; then
		echo "ret_tmp: $ret_tmp"
	fi
    case "$ret_tmp" in
        0) echo "patching was successfull";;
        1) echo "breaked current patching";;
        2) echo "canceled current patching";;
        *) echo "unknown state, ret_tmp: $ret_tmp"; exit 2;;
    esac
	
	if [[ "$exit_val" -lt "$ret_tmp" ]]; then
		exit_val=$ret_tmp
		if [[ $dbg_m == 1 ]]; then
            echo "exit_val: $exit_val"
        fi
	fi
done

exit $exit_val
