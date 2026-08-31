#!/bin/zsh

set -euo pipefail

print 'Available Android Virtual Devices:'
print '    Name: anonymous-fixture'
print "    Path: ${OMF_FAKE_AVD_PATH:?}"
if [[ -n ${OMF_FAKE_SECOND_AVD_PATH:-} ]]; then
  print '    Name: anonymous-fixture-second'
  print "    Path: ${OMF_FAKE_SECOND_AVD_PATH}"
fi
