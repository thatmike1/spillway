# Movement research source metadata

[movement-sources.json](movement-sources.json) records the 24 successful public
source downloads used by the R14 movement research. Each entry contains its URL,
SHA-256 and recorded fetch timestamp (UTC, 8 November 2026). This is original
provenance metadata, not a copy of the downloaded code or text. Third-party
snapshots are not kept in Git; neither the game nor the independent movement
oracle needs them at runtime.

The SHA-256 identifies the original downloaded response bytes, before any local
snapshot compression. For the source archive URL, it identifies the downloaded
`.tar.gz` bytes themselves, not an extracted tree or a decompressed tar file. The
metadata was checked against the research inventory, its compressed-file checksums
and the original response hashes. Public URLs contain no credentials or private
workspace paths. Failed fetches have no downloaded bytes to hash and are not
included; the [movement report](../movement-reference.md#commands-results-and-remaining-limits)
retains the research limits.

To inspect a reference again, fetch its URL into a directory outside the repository
and compare its SHA-256 with the recorded value. Several URLs name mutable branches
or unversioned gist content: they may now return different bytes or be unavailable.
A mismatch is a different revision, not a replacement for the historical reference.
Only the two SDK URLs containing a commit ID select an explicit source revision;
these records do not promise permanent availability of any upstream response.

The independent mathematical checks and predictions can be regenerated without
fetching any third-party material:

```sh
python3 tests/movement_oracle.py --self-test
python3 tests/movement_oracle.py
```
