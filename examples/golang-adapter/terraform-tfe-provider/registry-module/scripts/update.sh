#!/bin/bash
state=$(cat)
echo $state > state.json
../../../modules/golang/linux -name=registry-module -command=update -state=state.json
cat state.json
rm state.json
