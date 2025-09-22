#!/bin/sh
SERVER=root@dcon-elixir.ftes.de
copy(){ scp $1 $SERVER:app/$1; }

copy lib/my_system/math.ex
copy lib/my_system_web/math.ex
ssh $SERVER 'bash -lc "cd app; mix upgrade"'
