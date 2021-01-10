import unittest
import strutils

import hostname

test "hostname is not empty":
  check not isEmptyOrWhitespace(getHostname())
