# AMSMB2 with Lanternfish's patch

This is AMSMB2 at upstream `master`, commit `90737c4` (2026-04-24, four commits after the
4.0.3 release; <https://github.com/amosavian/AMSMB2/tree/90737c4>), with libsmb2 at commit
`aedafb2` (`libsmb2-6.2-163-gaedafb2`, 2026-01-27) as that commit names it, and Lanternfish's
changes to AMSMB2's Swift sources below (D-299). libsmb2 is not changed. The patched source is
published at <https://github.com/fmeesters/AMSMB2/tree/master-90737c4-lanternfish.2>, the
version the Acknowledgements screen names (`LanternfishSMB.amsmb2Version`).

## History

- **4.0.3-lanternfish.1** (2026-11-18): AMSMB2 4.0.3 with libsmb2 `aff9fa6` and patch 1.
- **master-90737c4-lanternfish.2** (2026-11-18): upstream's commits after 4.0.3 taken in
  (an empty password sent as none; `disconnect()` no longer frees folders and files, as libsmb2
  no longer keeps lists of them; a folder watched for changes opened without
  `FILE_NO_INTERMEDIATE_BUFFERING`; swift-system's `Errno` and `FileDescriptor`, renamings;
  the timeout also set in libsmb2), and with them libsmb2 from `aff9fa6` to `aedafb2`
  (security fixes for out-of-bounds writes a server could cause, responses to cancelled
  requests, a crash in change notifications, credits, socket writes). Patch 1 again on top,
  and patch 2.

## Patch 1 (2026-11-18): a request given up on closes the connection (`AMSMB2/Context.swift`)

`SMB2Client.wait_for_reply` threw on a timeout or a failed `poll()` and left the request
queued in libsmb2, its callbacks pointing at the `CBData` on the stack and at the request's
folder or file. Its reply, read later by the next request or by `disconnect()`, then called
into memory that was gone. In 4.0.3 `disconnect()` freed every folder first:
`EXC_BAD_ACCESS` in libsmb2's `query_cb` during `SMB2Manager.disconnectShare(gracefully:
false)`, seen at launch on the user's NAS (the server answered the queued directory query with
`STATUS_NETWORK_NAME_DELETED`). Upstream `master` no longer frees the folders there, but the
late callback still reads the dead `CBData`, and the test below still crashes on it.

- When waiting fails, the context is destroyed (`abandonConnection()`). libsmb2 closes the
  socket before it cancels what is queued, and `generic_handler` ignores callbacks without a
  socket, so nothing calls back into a stack frame that is gone. The client then reports
  `ENOTCONN`; Lanternfish's connection pool opens a new connection.
- `poll()` failing with `EINTR` or `EAGAIN` is tried again. The check compared the class's own
  `errno` property (the last NT status mapped to POSIX) instead of C's `errno`, so an
  interrupted poll gave the request up.

Reproduced by `SMBAbandonedRequestTests` in `LanternfishSMBTests` (a relay holds the server's
replies until a listing times out, then lets them through before the disconnect): the test
process crashed with SIGSEGV on 4.0.3 and on `master` at `90737c4`, and passes with the patch.

## Patch 2 (2026-11-18): an unused variable left out (`AMSMB2/Context.swift`)

`SMB2Client.wait(_:)` (an unfinished async variant upstream does not call) declared
`startDate` without using it; Lanternfish builds its packages with warnings as errors.

## Also left out

The package's own test target and its swift-atomics dependency (used by those tests only);
swift-system, which upstream links only off Apple's platforms (on them `System` is Apple's);
upstream's `CLAUDE.md` and the files for its CI and Docker. libsmb2's sources are copied in
here (Lanternfish's repository); upstream and the published fork have them as a git submodule
at `aedafb2`, the same files.
