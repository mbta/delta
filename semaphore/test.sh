#!/bin/bash
set -e

mix coveralls.json &&
bash <(curl -s https://codecov.io/bash) -t $CODECOV_TOKEN
