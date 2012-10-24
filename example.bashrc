# Example bash functions for use with uselect

#------------------------------------------------------------------------------
# Editing functions: fe ge le

# fe <ff-args> - find files by name and edit (*F*ind and *E*dit)
fe() {
    uedit $( ff "$@" | uselect -s "fe $*" )
}

# ge <ack-args> - grep files by content and edit (*G*rep and *E*dit)
ge() {
    uedit $( ack --heading --break "$@" | uselect -s "ge $*" -i -m '^\d+[:-]' )
}

# le <locate-args> - locate files by name and edit (*L*ocate and *E*dit)
le() {
    uedit $( locate "$@" | perl -nlE 'say if -f' | uselect -s "le $*" )
}


#------------------------------------------------------------------------------
# Misc functions: fx hx ugit

# aptinfo <aptitude-search-pattern>
# * combined aptitude search and aptitude show
aptinfo() {
    aptitude search -F '%p %d %V %v' "$@" |\
        uselect -s 'Show package info' |\
        awk '{ print $1 }' |\
        xargs aptitude show
}

# fx <command> [args] <ff-search-term> - find files and execute
# * eg. fx tar -czvf source.tar.gz .c
# * use '' as the search term to match everything
fx() {
    # "${!#}"              == $ARGV[n-1]
    # "${@:1:$(($# - 1))}" == $ARGV[0..n-2]
    "${@:1:$(($# - 1))}" $( ff "${!#}" | uselect -s "$*" );
}

# hx [fgrep-args] - history search and execute
# * select a command from your history and execute it
# * optionally specify fgrep args to narrow the list
# * eg. hx mount
# * eg. hx -i nocase
hx ()
{
    local cmd=$( fc -l -1 1 | fgrep "${@:- }" | uselect -1 | awk '{print $1}' )
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

# uedit [files] - basic $EDITOR wrapper
# * echoes file arguments to stderr
# * exits if there are no filenames
uedit() {
    if [ $# -gt 0 ]; then
        echo $EDITOR $@ 1>&2
        $EDITOR "$@"
    fi
}

# ixargs command [args] - interactive xargs
# * used similar to xargs, but works with interactive programs
# * basic usage only, no xargs options are supported
ixargs() {
    # Read args from stdin into the $args array
    IFS=$'\n';
    set -f ;
    trap 'echo Aborted...' INT
    local args=( $( cat ) )   # read args from stdin
    trap INT
    set +f ;
    IFS=$' \t\n'

    # Reopen stdin to /dev/tty so that interactive programs work properly
    exec 0</dev/tty

    # Run specified command with the args from stdin
    [ -n "$files" ] && "$@" "${args[@]}"
}

# ff [fgrep-pattern] - list files matching pattern
# * pattern is simple string match against the relative path
ff() {
    ack -a -f | fgrep "$@" ;
}

