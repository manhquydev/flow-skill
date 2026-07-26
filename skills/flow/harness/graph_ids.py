"""Monotonic, lexicographically sortable ids for the graph executor (stdlib only).

Format: 16 hex chars of a strictly-increasing nanosecond timestamp + 6 hex chars of
random suffix, fixed width 22. Within one process ids are STRICTLY increasing (the
timestamp is bumped past the last issued value, so two calls in the same nanosecond
still order); across processes ordering follows wall clock at nanosecond grain and
the random suffix keeps ids unique — the same guarantee LangGraph's UUID6 checkpoint
ids provide, without a dependency. Fixed width makes string sort == numeric sort.
"""

import os
import threading
import time

_lock = threading.Lock()
_last_ns = 0


def after(prev):
    """An id strictly greater than `prev`. Used when the journal head was minted by a
    process whose clock ran ahead of ours: ordering here is lexicographic, so a plain
    timestamp id would silently sort BELOW the head and the write would be invisible."""
    with _lock:
        ts = int(prev[:16], 16) + 1
    return "%016x%s" % (ts, os.urandom(3).hex())


def new_id():
    global _last_ns
    with _lock:
        ns = time.time_ns()
        if ns <= _last_ns:
            ns = _last_ns + 1
        _last_ns = ns
    return "%016x%s" % (ns, os.urandom(3).hex())
