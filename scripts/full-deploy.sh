#!/bin/sh
SERVER=root@dcon-elixir.ftes.de

ssh $SERVER 'rm -rf app/lib; rm -rf app/assets'
scp -r lib $SERVER:app/lib
scp -r assets $SERVER:app/assets
ssh $SERVER 'bash -lc "cd app; _build/prod/rel/my_system/bin/my_system stop; mix assets.deploy; mix release --overwrite; _build/prod/rel/my_system/bin/my_system daemon"'
