#!/bin/sh
SERVER=root@dcon-elixir.ftes.de

ssh $SERVER 'tail -f app/_build/prod/rel/my_system/tmp/log/*'
