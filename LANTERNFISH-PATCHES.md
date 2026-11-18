# AMSMB2 4.0.3 with Lanternfish's patch

This is AMSMB2 4.0.3 (<https://github.com/amosavian/AMSMB2/tree/4.0.3>, commit `1726aaa`)
with libsmb2 6.1.0 as bundled there, and one change to AMSMB2's Swift sources (D-299).
libsmb2 is not changed. The patched source is published at
<https://github.com/fmeesters/AMSMB2/tree/4.0.3-lanternfish.1>, the version the
Acknowledgements screen names (`LanternfishSMB.amsmb2Version`).

## Patch 1 (2026-11-18): a request given up on closes the connection (`AMSMB2/Context.swift`)

`SMB2Client.wait_for_reply` threw on a timeout or a failed `poll()` and left the request
queued in libsmb2, its callbacks pointing at the `CBData` on the stack and at the request's
folder or file. Its reply, read later by the next request or by `disconnect()` (which calls
`smb2_free_all_dirs` first), then called into freed memory: `EXC_BAD_ACCESS` in libsmb2's
`query_cb` during `SMB2Manager.disconnectShare(gracefully: false)`, seen at launch on the
user's NAS (the server answered the queued directory query with
`STATUS_NETWORK_NAME_DELETED`).

- When waiting fails, the context is destroyed (`abandonConnection()`). libsmb2 closes the
  socket before it cancels what is queued, and `generic_handler` ignores callbacks without a
  socket, so nothing calls back into a stack frame that is gone. The client then reports
  `ENOTCONN`; Lanternfish's connection pool opens a new connection.
- `poll()` failing with `EINTR` or `EAGAIN` is tried again. The check compared the class's own
  `errno` property (the last NT status mapped to POSIX) instead of C's `errno`, so an
  interrupted poll gave the request up.

Reproduced by `SMBAbandonedRequestTests` in `LanternfishSMBTests` (a relay holds the server's
replies until a listing times out, then lets them through before the disconnect): the test
process crashed with SIGSEGV on 4.0.3 and passes with the patch.

Upstream has since removed the `smb2_free_all_dirs` / `smb2_free_all_fhs` calls from
`disconnect()` (commit `497ce6e`, after 4.0.3, not released). That alone still leaves the late
callback reading the dead `CBData`.

## Also left out

The package's own test target and its swift-atomics dependency (used by those tests only),
and the files for upstream's CI and Docker. libsmb2's sources are copied in here (Lanternfish's
repository); upstream and the published fork have them as a git submodule at libsmb2 commit
`aff9fa6`, the same files.
