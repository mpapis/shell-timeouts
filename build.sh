#!/bin/bash
source /etc/profile

case $(uname) in
  (Darwin)
    travis_list_children()
    {
      ps -o ppid= -o pid= -ax | awk '$1=='"$1"'{print $2}'
    }
    ;;
  (*)
    travis_list_children()
    {
      ps -o pid= --ppid $1
    }
    ;;
esac

travis_safe_kill() {
  ps aux | grep -v grep | grep $1 >/dev/null && kill ${2:-} $1
}

travis_kill_children_processes()
{
  while
    (( $# ))
  do
    travis_kill_children_processes $( travis_list_children $1 )
    travis_safe_kill $1 -9
    shift
  done
}

# () - subshell does not get new $$ / $PPID
detect_subshell_pid()
{
  ( sleep 1s; ) &
  _subshell_pid=$( ps -p $( ps -p $! -o ppid= ) -o ppid= )
}

travis_timeout_function()
(
  echo "Timeout ($1 seconds) started for: $3"
  trap "return 0" USR1
  sleep $1
  detect_subshell_pid
  echo
  echo "Timeout ($1 seconds) reached for: $3"
  echo
  travis_kill_children_processes $( travis_list_children $2 | grep -v "^[[:space:]]*${_subshell_pid}$" )
  travis_safe_kill $2
)

travis_timeout()
{
  typeset _my_timeout _waiter_pid _return
  _my_timeout=$1
  _return=0
  shift
  travis_timeout_function ${_my_timeout} $$ "$*" &
  _waiter_pid=$!
  echo "\$ $*"
ps ajxf | awk $$'==$3{print}'
  "$@" || _return=$?
  travis_safe_kill $_waiter_pid -USR1
  return ${_return}
}

travis_timeout_function 5 $$ "Script timeout!" &
_global_waiter_pid=$!

travis_timeout 3 bundle install
travis_timeout 3 bundle exec rake

travis_safe_kill $_global_waiter_pid -USR1
