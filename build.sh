#!/bin/bash
source /etc/profile

case `uname` in
  (aDarwin)
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

  travis_timeout_function()
  (
    typeset _my_pid
    trap "return 0" USR1
    sleep $1
    ( sleep 1s; ) &
    _my_pid=$( ps -p $( ps -p $! -o ppid= ) -o ppid= ) # () - subshell does not get new $$ / $PPID
    echo
    echo "Timeout ($1 seconds) reached for: $3"
    echo
    travis_kill_children_processes $( travis_list_children $2 | grep -v "^[[:space:]]*${_my_pid}$" )
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
  "$@" || _return=$?
  travis_safe_kill $_waiter_pid -USR1
  return ${_return}
}

travis_timeout_function 5 $$ "Script timeout!" &
_global_waiter_pid=$!

ps ajxf | awk $$'==$3{print}'
echo '$ bundle install'
travis_timeout 3 bundle install
ps ajxf | awk $$'==$3{print}'
echo '$ bundle exec rake'
travis_timeout 3 bundle exec rake
ps ajxf | awk $$'==$3{print}'

travis_safe_kill $_global_waiter_pid -USR1
