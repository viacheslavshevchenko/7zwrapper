#!/usr/bin/env bash

exec erl -pa $PWD/ebin \
         -sname 7zwrapper \
         -boot start_sasl
