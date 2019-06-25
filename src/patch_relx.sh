#!/bin/ash
patch -u _build/default/deps/relx/priv/templates/nodetool patches/nodetool.diff
patch -u _build/default/deps/relx/priv/templates/extended_bin patches/extended_bin.diff
