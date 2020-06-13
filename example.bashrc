# Example bash functions for use with uselect

has() {
    type -t "$@" > /dev/null
}

#------------------------------------------------------------------------------
# Editing functions: fe ge le

# fe <ff-args> - find files by name and edit (*F*ind and *E*dit)
fe() {
    uedit $( ff "$@" | uselect -s "fe $*" )
}

# ge <ack-args> - grep files by content and edit (*G*rep and *E*dit)
if has ag; then
    ge() {
        uedit $( ag --heading --break "$@" | uselect -s "ge $*" -i -m '^\d+:' )
    }
elif has ack; then
    ge() {
        uedit $( ack --heading --break "$@" | uselect -s "ge $*" -i -m '^\d+:' )
    }
else
    ge() {
        echo Please install ack or ag
    }
fi

# le <locate-args> - locate files by name and edit (*L*ocate and *E*dit)
le() {
    uedit $( locate "$@" | perl -nlE 'say if -f' | uselect -s "le $*" )
}


#------------------------------------------------------------------------------
# Misc functions: fx hx ugit

# aptinfo <aptitude-search-pattern>
# * combined aptitude search and aptitude show
aptinfo() {
    aptitude search -w $( tput cols ) -F '%p %d %V %v' "$@" |\
        uselect -s 'Show package info' |\
        awk '{ print $1 }' |\
        xargs aptitude show
}

# fx <command> [args] <ff-search-term> - find files and execute
# * eg. fx tar -czvf source.tar.gz .c
# * use '' as the search term to match everything
fx() {
    # eg. fx $command-and-args $ff-search-term
    local cmd="${@:1:$(($# - 1))}"      # ARGV[0 .. N-2]
    local pat="${!#}"                   # ARGV[N-1]

    # This whole hoo-har is so we split on newlines and not spaces, so that
    # if we get [ 'file1', 'file 2' ] from uselect, then the files array
    # contains two elements, not three.
    local _IFS="$IFS"
    local out=$( ff "$pat" | uselect -s "$*" )
    IFS=$'\n'
    local files=( $out )
    IFS="$_IFS"

    runv $cmd "${files[@]}"
}


# hx [fgrep-args] - history search and execute
# * select a command from your history and execute it
# * optionally specify fgrep args to narrow the list
# * eg. hx mount
# * eg. hx -i nocase
hx ()
{
    local cmd=$( history | reverse | fgrep "${@:- }" | tail -n +2 | uselect -1 | awk '{print $1}' )
    [[ -n "$cmd" ]] && fc -s $cmd
}

# ugit <command> [options]
# * use ugit in a similar fashion to how you'd use git, but leave the filenames
#   out - you'll be presented with a list of files in uselect
#
# eg.  ugit diff
#      ugit add
#      ugit add -p
#      ugit reset HEAD
#
# BEWARE: there's no safety guard on this - not all git commands make sense
#         with ugit
ugit() {
    git status -s | uselect -s "git $*" | sed -e 's/^...//' | ixargs git "$@"
}

#------------------------------------------------------------------------------
# Support functions

# reverse() - reverses the stream, first to last
if type -t tac > /dev/null; then
    reverse() { tac; }
else
    reverse() { tail -r; }
fi

# uedit [files] - basic $EDITOR wrapper
# * echoes file arguments to stderr
# * exits if there are no filenames
uedit() {
    if [ $# -gt 0 ]; then
        runv ${UEDITOR:-$EDITOR} "$@"
    fi
}

# ixargs command [args] - interactive xargs
# * used similar to xargs, but works with interactive programs
# * basic usage only, no xargs options are supported
ixargs() {
    # Read args from stdin into the $args array
    local _IFS="$IFS"
    IFS=$'\n';
    set -f ;
    trap 'echo Aborted...' INT
    local args=( $( cat ) )   # read args from stdin
    trap INT
    set +f ;
    IFS="$_IFS"

    # Reopen stdin to /dev/tty so that interactive programs work properly
    exec 0</dev/tty

    # Run specified command with the args from stdin
    [ -n "$args" ] && runv "$@" "${args[@]}"
}

# ff [fgrep-pattern] - list files matching pattern
# * pattern is simple string match against the relative path
if has ag; then
    ff() {
        ag -l | sort | fgrep "${@:- }" ;
    }
elif has ack; then
    ff() {
        ack -f | fgrep "${@:- }" ;
    }
else
    ff() {
        echo Please install ack or ag
    }
fi

# echoq [args]
# Echo-quoted - shell-escapes the arguments before printing, so that they
# can be copied and pasted back into the shell.
echoq() {
    printf '%q ' "$@"
    printf "\n"
}

# runv [command-line] - run verbosely
# Echo the command to stderr with quoting, and then run it
runv() {
    echoq "$@" 1>&2
    "$@"
}
