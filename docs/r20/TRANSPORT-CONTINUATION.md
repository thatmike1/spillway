# R20 capture transport continuation

All 48 actual `73999bd1c` plays and their source postflight completed before compression finalization. The original helper recursively measures the entire evidence tree after each input chunk, including the 1,021-byte determinism challenge. It was stopped after safely canonicalizing one ghost stream. All 144 decompressed hashes and lengths remain exact; 143 original compressed hashes remain exact. The old compressed hash for that one stream is retained, but its original compressed bytes are no longer present. Partial trace output and the stopped process/log are preserved separately.

`tools/finalize-r20-captured-parity.py` is a separately pinned postprocessor. It requires explicit reviewed SHA256s of itself and the stopped inventory, the original candidate/identity/scoring inputs, the complete closed capture and source-cleanup receipts, and all 144 stopped stream hashes. The only reviewed prior replacement is `breakwater-basic/old/evaluator/ghost.jsonl.gz`. Its recompression must match both the original decompressed receipt and its current canonical gzip exactly. Any other changed gzip or any raw-byte mismatch refuses. It does not launch Godot or replay a route.

Before each stream the continuation inventories every evidence file. During every chunk it keeps the original HOME gate and checks the initial allocated blocks plus the growing output. After close it checks final allocation and refuses changes to any other file's inode, size, modification time or allocation. This requires an exclusive writer to the closed capture directory. It retains the original file-allocation scope, not a process-RSS claim.

The postprocessor writes the original transport format and retains each original compressed hash in `streamed_gzip_sha256`. It verifies raw SHA256/byte counts and two chunk sizes for every stream. `TRANSPORT-PROCESSOR.json` names the separate processor, original driver/core hashes, captured helper inventory, stopped inventory and original stream receipts. `TRANSPORT.json` additionally pins the separate processor and stopped inventory. Original capture identities and reports are retained.

The unchanged original full verifier then independently rereads all compressed and decompressed hashes, performs every physical/input/scoring/recording/ghost comparison and executes original and candidate negative controls. A subsequent ordinary `--audit` with the unchanged checker remains required. No acceptance follows merely from compression finishing.

Verified engine-free regression command, from the project:

```sh
python3 -B tests/test_r20_transport_continuation.py
```

Ten tests cover exact output against the original implementation, chunk-independent gzip, two tree scans regardless of chunk count, initial/growing allocation refusals, unrelated-file mutation refusal, source preservation, existing outputs/symlinks, invalid chunks, all 144 synthetic streams passing the original transport guard, the explicitly prior-canonicalized stream, and refused changed raw/unapproved compressed bytes. These tests do not accept a gameplay matrix.

The continuation takes the original candidate, baseline, runtime freeze/identity, scoring/identity-contract paths and hashes, plus `--processor-sha256`, `--stopped-inventory-sha256` and `--out`. Contracts continue naming the actual captured commit. A newer release may use its proof only through an explicit byte-exact runtime/helper equivalence record. The 26 original capture and audit helpers stay unchanged.
