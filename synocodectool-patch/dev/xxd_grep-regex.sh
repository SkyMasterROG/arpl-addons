#!/bin/ash

# https://en.wikipedia.org/wiki/Almquist_shell
# https://www.cyberciti.biz/faq/grep-regular-expressions/
# 
# https://stackoverflow.com/questions/6319878/using-grep-to-search-for-hex-strings-in-a-file
# https://stackoverflow.com/questions/1898553/return-a-regex-match-in-a-bash-script-instead-of-replacing-it
# 
# https://google.github.io/styleguide/shellguide.html
# https://www.baeldung.com/linux/use-command-line-arguments-in-bash-script
# 
# Created by SkyMaster for Fabio Belavenuto's ARPL project
# https://github.com/SkyMasterROG/arpl-addons
# 03/2023
# 

#set -eo pipefail;
#shopt -s nullglob;


#variables

script_name="${0##*/}"
script_dir="${0%/*}"
script_log="$script_dir/$script_name.log"
log_path=""
opmode="help"
dbg_m=0
exit_val=100

bin_file="synocodectool"
info_file="INFO"
declare -a binpath_list=()
declare -a package_check_list=()


#sources
source "/etc/VERSION"
source "$script_dir/patche_declares"


#functions

print_usage() { 
printf "
SYNOPSIS
    xxd_grep-regex.sh [-e|-g|-h|-l|-p]
DESCRIPTION
    check \"synocodectool\" since DSM 7+
        -e      extended check synocodectool
        -g      check synocodectool
        -h      print this help message
        -l      list known DSM versions
        -p      list known packages
"
}

list_versions () {
    if ! (( ${#versions_list[@]} )); then
        echo "could not find versions_list" | tee -a $log_path
        exit 1
    fi

    echo "known DSM versions"
    for i in "${versions_list[@]}"; do
        echo "$i"
    done
}

list_packages () {
    if ! (( ${#packages_list[@]} )); then
        echo "could not find packages_list" | tee -a $log_path
        exit 1
    fi

    echo "known packages"
    for i in "${packages_list[@]}"; do
        echo "$i"
    done
}

check_version () {
    echo "FUNCTION: ${FUNCNAME[*]}" >&2

    local ver="$1"

    if ! (( ${#versions_list[@]} )); then
        echo "could not find versions_list" | tee -a $log_path
        return 1
    fi

    for i in "${versions_list[@]}"; do
        if [[ "$i" == "$ver" ]]; then
            return 0
        fi
    done
    
    return 1
}

create_binpath_list () {
    echo "FUNCTION: ${FUNCNAME[*]}" >&2

    if ! (( ${#dir_list_f[@]} )); then
        echo "could not find dir_list_f" | tee -a $log_path
        return 1
    fi

    for i in "${dir_list_f[@]}"; do
        local var1=""
        local var2=""
        local var3=""
        local -a dir_list_1=()
        #local -a dir_list_2=()
        
        if [[ "$i" =~ \%d && "$i" =~ \%s ]]; then
            #echo "dir_list_f entry contain %d and %s"
            #echo "i: $i"

            # https://superuser.com/questions/1001973/bash-find-string-index-position-of-substring
            # https://stackoverflow.com/questions/19482123/extract-part-of-a-string-using-bash-cut-split

            # https://stackoverflow.com/questions/13570327/how-to-delete-a-substring-using-shell-script
            var1=$(echo $i | grep -o '^[^%d]*') # "delete" substring from '%d'
            #echo "var1: $var1"

            # https://stackoverflow.com/questions/14352290/listing-only-directories-using-ls-in-bash
            # https://stackoverflow.com/questions/21792385/how-to-use-ls-to-list-out-files-that-end-in-numbers
            # https://stackoverflow.com/questions/46154279/how-can-i-split-the-string-output-of-an-ls-command-into-an-array-on-just-the-fil
            dir_list_1=($(ls -d "$var1"{1..12} 2>/dev/null))
            echo "dir_list_1: ${dir_list_1[@]}"

            if (( ${#dir_list_1[@]} )); then
                var2="$var1%d" # add char '%d'
                for j in "${dir_list_1[@]}"; do
                    #echo "tmp_list entry: $j"
                    # https://stackoverflow.com/questions/13210880/replace-one-substring-for-another-string-in-shell-script
                    var1="${i/$var2/$j}" # replace substring "var2" with "j" in string "i"
                    

                    for k in "${packages_list[@]}"; do
                        var3="${var1/\%s/$k}" # replace substring
                        #echo "directory to test: $var3"

                        if [ -f "$var3/$bin_file" ]; then
                            binpath_list+=( "$var3/$bin_file" )
                            echo "added binpath entry: $var3/$bin_file" | tee -a $log_path
                        fi
                    done
                done
            fi

        elif [[ "$i" =~ \%d ]]; then
            echo "dir_list_f entry contain %d"
            echo "i: $i"

        elif [[ "$i" =~ \%s ]]; then
            echo "dir_list_f entry contain %s"
            echo "i: $i"

        elif [[ -f "$i/$bin_file" ]]; then
            #echo "dir_list_f entry is absolut"
            #echo "i: $i"

            binpath_list+=( "$i/$bin_file" )
            echo "added binpath entry: $i/$bin_file" | tee -a $log_path
        fi
    done

    return 1
}

get_pack_info () {
    echo "FUNCTION: ${FUNCNAME[*]}" >&2

    local ret_val=100

    # https://serverfault.com/questions/219306/control-a-bash-script-with-variables-from-an-external-file

    #local pack_dir="$1"
    #local pack_name="$2"
    local pack_path=""
    local pack_info=""

    #pack_info=/var/packages/CodecPack/INFO
    
    #pack_info="$pack_path/INFO"


    if ! (( ${#dir_list_f[@]} )); then
        echo "could not find dir_list_f" | tee -a $log_path
        return 1
    fi

    for i in "${dir_list_f[@]}"; do
        local var1=""
        local var2=""
        local var3=""
        local -a dir_list_1=()
        
        if [[ "$i" =~ \%d ]]; then
            continue

        elif [[ "$i" =~ packages && "$i" =~ \%s ]]; then
            #echo "dir_list_f entry contain %d and %s"
            echo "i: $i"

            for k in "${packages_list[@]}"; do
                # https://phoenixnap.com/kb/bash-printf
                #printf -v var1 "$i" $k # print f-string to var1
                var1="${i/\%s/$k}" # replace substring "%s" with "k" in string "i"
                echo "directory to test: $var1"

                # https://www.cyberciti.biz/faq/get-octal-file-permissions-from-command-line-on-linuxunix/
                #stat -c '%a' /etc/passwd

                if [ -f "$var1/$info_file" ]; then
                    var2=$(stat -c '%a' $var1/$info_file)
                    echo "var2: $var2"

                    # load info values
                    source $var1/$info_file

                    echo "info_file: $package $version $arch $os_min_ver $toolkit_version $create_time"

                    # unload info values
                    #...
                fi

                # /var/packages/CodecPack/target/bin
                if [ -f "$var1/target/bin/$bin_file" ]; then
                    var2=$(stat -c '%a' $var1/target/bin/$bin_file)
                    echo "var2: $var2"

                    get_offsets "$var1/target/bin/$bin_file" || ret_val=$?
                    ret_val=$?
                fi
            done
        fi
    done

    return 0


    #cat $pack_info | while read -a HR ; do
    #    [[ -z ${HR[0]} ]] && continue  # skip empty lines
    #
    #    package=${HR[0]}
    #    version=${HR[1]}
    #    arch=${HR[5]}
    #    os_min_ver=${HR[6]}
    #    toolkit_version=${HR[58]}
    #    create_time=${HR[59]}
    #done

    echo "$package $version $arch $os_min_ver $toolkit_version $create_time"
}

misc_dummy () {
    echo "FUNCTION: ${FUNCNAME[*]}" >&2

    echo "script_name: $script_name"
    echo "script_dir: $script_dir"

    #LANG=C grep --only-matching --byte-offset --binary --text --perl-regexp "<\x-hex pattern>" <file>

    echo
    echo "xxd .. grep .. proc.."
    echo "grep_pattern: $grep_pattern"

    echo
    # xxd -g bytes    number of octets per group in normal output. Default 2 (-e: 4).
    xxd -g 16 $script_dir/synocodectool.42962-4.dev.patch | grep --basic-regexp $grep_pattern
    echo "xxd .. grep .. result: $?"

    echo
    xxd -g 16 $script_dir/synocodectool.18461b62.42962-4.dev.org | grep --basic-regexp $grep_pattern
    echo "xxd .. grep .. result: $?"
}

get_offsets () {
    echo "FUNCTION: ${FUNCNAME[*]}" >&2

    local bin_path="$1"
    local ret_last=100
    local res_tmp=""

    local synocodectool_hash="$(sha1sum "$bin_path" | cut -f1 -d\ )"
    ret_last=$?
    echo "ret_last: $ret_last"

    #if [[ ! "$ret_last" == 0 ]]; then
        if [[ -z $synocodectool_hash ]]; then
            echo "sha1sum || cut return: $ret_last" | tee -a $log_path

            if ! [[ -f $bin_path ]]; then
                echo "bin_path fail: $bin_path" | tee -a $log_path
            fi

            return $ret_last
        fi

        #echo "bin_path fail: $bin_path, hash: $synocodectool_hash" | tee -a $log_path
        #return 2
    #fi

    
    echo "bin_path: $bin_path, hash: $synocodectool_hash" | tee -a $log_path

    if [[ "${binhash_version_list[$synocodectool_hash]+isset}" ]]; then
        #echo ${binhash_pattern_list[$synocodectool_hash]/'\n'/ }
        local pattern_array=(${binhash_pattern_list[$synocodectool_hash]/'\n'/ }) # replace substring '\n' with ' ' in string
        #echo "pattern_array: ${pattern_array[@]}"

        echo "Detected valid synocodectool. Looking for offsets.." | tee -a $log_path

        for pattern in "${pattern_array[@]}"; do
            echo "pattern: $pattern" | tee -a $log_path

            res_tmp=$(xxd -u -g 16 $bin_path | grep --basic-regexp $pattern)
            ret_last=$?
            #echo "xxd .. grep .. result: $ret_last"
            echo "result: $res_tmp" | tee -a $log_path
        done

        #return 0
        return $ret_last
    elif [[ ! -z $synocodectool_hash ]]; then
        echo "Detected unknown synocodectool. Try binhash_pattern_list.." | tee -a $log_path
        
        echo "$bin_path hash sha1sum: $synocodectool_hash" | tee -a $log_path

        for pattern_string in "${binhash_pattern_list[@]}"; do
            #echo ${binhash_pattern_list[$synocodectool_hash]/'\n'/ }
            local pattern_array=(${pattern_string/'\n'/ })
            #echo "pattern_array: ${pattern_array[@]}"
            

            for pattern in "${pattern_array[@]}"; do
                echo "pattern: $pattern" | tee -a $log_path

                res_tmp=$(xxd -u -g 16 $bin_path | grep --basic-regexp $pattern)
                ret_last=$?
                #echo "xxd .. grep .. result: $ret_last"
                echo "xxd .. grep .. result: $res_tmp" | tee -a $log_path
            done
        done

        return $ret_last
    fi
	
	return 1
}

check_ext () {
    echo "FUNCTION: ${FUNCNAME[*]}" >&2

    local is_ext="$1"
    local ret_val=100


    dsm_version="$productversion-$buildnumber-$smallfixnumber"
    if [[ -z $dsm_version ]] ; then
        echo "could not fetch dsm_version" | tee -a $script_log
        return 1
    fi

    log_path="$script_dir/$dsm_version.log"

    if ! check_version $dsm_version; then
        echo "dsm_version unknown: $dsm_version, builddate $builddate" | tee -a $log_path
    else
        echo "dsm_version: $dsm_version, builddate $builddate" | tee -a $log_path
    fi

    # is extended chek
    #echo "is_ext: $is_ext"
    if [[ "$is_ext" == 1 ]]; then
        echo "extended chek"
        get_pack_info
        ret_val=$?

        return $ret_val
    fi

    # is native chek
    echo "native chek"
    create_binpath_list
    ret_val=$?

    if  ! (( ${#binpath_list[@]} )); then
        echo "could not find $bin_file" | tee -a $log_path
        return 1
    fi

    for path in "${binpath_list[@]}"; do

        get_offsets "${path}" || ret_val=$?
        ret_val=$?
        
        case "$ret_val" in
            0) echo "successfull" | tee -a $log_path;;
            1) echo "breaked" | tee -a $log_path;;
            2) echo "canceled" | tee -a $log_path;;
            *) echo "unknown state, ret_val: $ret_val" | tee -a $log_path;;
        esac
    done

    return $ret_val
}


#main
echo "$script_name started, $(date)" | tee -a $script_log

while getopts eghlp flag; do
    case "${flag}" in
        e) opmode="checkext";;
        g) opmode="check";;
        h) opmode="${opmode}";;
        l) opmode="listversions";;
        p) opmode="listpackages";;
        *) opmode="help"; echo "opmode set to $opmode";;
    esac
done

case "${opmode}" in
    checkext) check_ext 1;;
    check) check_ext 0; exit_val=$?;;
    help) print_usage; exit_val=2;;
    listversions) list_versions; exit_val=2;;
    listpackages) list_packages; exit_val=2;;
    *) echo "Incorrect combination of flags. Use option -h to get help."; exit 2;;
esac

echo "$script_name exit with \"$exit_val\", $(date)" | tee -a $script_log
exit $exit_val
