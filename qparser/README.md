# qparser

This folder contains the curated parser refactor upload from the local FastRMT workspace.

Included here:
- Split parser RTL modules
- Wrapper and parser-focused testbenches
- Long/short parser initialization and `.mem` table files
- XSim regression script used for verification

Verified locally before upload:
- `tb_parser_staged`
- `tb_rmt_wrapper`
- `tb_rmt_wrapper_long_burst`
- `tb_rmt_wrapper_long_mpls_finalize_burst`
- `tb_rmt_wrapper_long_mixed_burst`

Notes:
- The long-burst fix depends on the `rmt_wrapper` input-side valid/ready buffer change.
- Files are uploaded under `qparser/` to avoid overwriting unrelated repository content on the branch root.
