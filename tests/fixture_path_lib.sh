#!/usr/bin/env bash
# Controlled-PATH fixtures must forward tools, not relocate their runtimes.
# In particular, Bash builtins (e.g. pwd) are not filesystem link targets.
fixture_forward_tool() { # destination, command name, original executable
  printf '#!/bin/bash\nexec %q "$@"\n' "$3" > "$1/$2"
  chmod +x "$1/$2"
}

fixture_add_python() { # destination, command name, optional original executable
  local dest="$1" name="$2" resolved native runtime="$1/.python-runtime"
  resolved="${3:-$(type -P "$name" 2>/dev/null)}"
  [ -f "$resolved" ] || return 0
  native="$("$resolved" -c 'import os, sqlite3; print(os.name)' 2>/dev/null | tr -d '\r\n')" || return 1
  case "$native" in posix|nt) ;; *) return 1 ;; esac
  # Remove aliases first: writing through a Unix symlink would modify the host.
  rm -f "$dest/$name" "$dest/$name.exe"
  if [ "$native" = nt ]; then
    # Native Popen cannot launch a shell wrapper. Use CPython's stdlib venv
    # redirector, whose adjacent pyvenv.cfg points at the original Python home
    # (including its DLLs, stdlib and sqlite3), without adding that home to PATH.
    if [ ! -f "$runtime/pyvenv.cfg" ]; then
      "$resolved" -m venv --without-pip --copies "$runtime" || return 1
      cp "$runtime/pyvenv.cfg" "$dest/pyvenv.cfg" || return 1
    fi
    # Keep the exact extensionless name for command -v assertions and the .exe
    # spelling for Win32 CreateProcess's executable-name resolution.
    cp "$runtime/Scripts/python.exe" "$dest/$name" || return 1
    cp "$runtime/Scripts/python.exe" "$dest/$name.exe" || return 1
  else
    fixture_forward_tool "$dest" "$name" "$resolved" || return 1
  fi
}
