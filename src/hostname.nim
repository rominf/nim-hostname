const weirdTarget = defined(nimscript) or defined(js)

when weirdTarget:
  {.error: "hostname library is not available on the NimScript/js target".}

import os

when defined(windows):
  import winlean
  # https://docs.microsoft.com/en-us/windows/win32/api/sysinfoapi/ne-sysinfoapi-computer_name_format
  const ComputerNamePhysicalNetBIOS = 4
  const ComputerNamePhysicalDnsHostname = 5
elif defined(posix):
  import posix

proc getHostname*(): string {.tags: [ReadIOEffect].} =
  ## Returns the local hostname (not the FQDN).
  ## On Windows (see
  ## https://docs.microsoft.com/en-us/windows/win32/sysinfo/computer-names)
  ## returns ComputerNamePhysicalDnsHostname.
  # On POSIX SUSv2 guarantees that "Host names are limited to 255 bytes".
  # https://tools.ietf.org/html/rfc1035#section-2.3.1
  # https://tools.ietf.org/html/rfc2181#section-11
  const size = 256
  result = newString(size)
  when defined(windows):
    proc getComputerNameExA(nameType: cint, name: cstring, len: PDWORD): WINBOOL
      {.stdcall, dynlib: "kernel32", importc: "GetComputerNameExA", sideEffect.}
    var resultLen: DWORD = DWORD(size)
    let success = getComputerNameExA(ComputerNamePhysicalDnsHostname,
                                     result.cstring, resultLen.addr) != 0
  elif defined(posix):
    let success = gethostname(result, size) == 0
    let resultLen = len(cstring(result))
  else:
    doAssert false, "getHostname failed: OS is not supported"
  if not success:
    raiseOSError(osLastError())
  result.setLen(resultLen)

proc setHostname*(name: string) =
  ## Sets host name.
  ## Available in Windows, Linux (including Android), OS X, BSD, Haiku, and QNX
  ## distributions.
  ## Requires root priviledges on POSIX and administrator privileges on
  ## Windows.
  ## Windows notes (see
  ## https://docs.microsoft.com/en-us/windows/win32/sysinfo/computer-names):
  ## * Sets both ComputerNamePhysicalNetBIOS and
  ##   ComputerNamePhysicalDnsHostname.
  ## * Name changes made by this function call do not take effect until the user
  ##   restarts the computer.
  var success: bool
  when (defined(android) or defined(haiku) or defined(linux) or
        defined(netbsd) or defined(openbsd) or defined(qnx)):
    proc setHostname(name: cstring, len: csize_t): cint
      {.importc: "sethostname", header: "<unistd.h>", sideEffect.}
    success = setHostname(name.cstring, csize_t(name.len)) == 0
  elif defined(dragonfly) or defined(freebsd) or defined(osx):
    proc setHostname(name: cstring, len: cint): cint
      {.importc: "sethostname", header: "<unistd.h>", sideEffect.}
    success = setHostname(name.cstring, cint(name.len)) == 0
  elif defined(windows):
    proc setComputerNameExA(nameType: cint, name: cstring): WINBOOL
      {.stdcall, dynlib: "kernel32", importc: "SetComputerNameExA", sideEffect.}
    let oldName = getHostname()
    success = setComputerNameExA(ComputerNamePhysicalNetBIOS, name.cstring) != 0
    if not success:
      raiseOSError(osLastError(), name)
    success = setComputerNameExA(ComputerNamePhysicalDnsHostname,
                                 name.cstring) != 0
    if not success:
      discard setComputerNameExA(ComputerNamePhysicalNetBIOS, oldName)
  else:
    doAssert false, "setHostname failed: OS is not supported"
  if not success:
    raiseOSError(osLastError(), name)
