# PParser Hardware Reproduction Plan

## 1. Goal

This document gives a hardware-focused reproduction plan for the paper:

- `Memory-efficient programmable packet parsing for multi-tenant terabit networks`
- DOI: `10.1016/j.comnet.2025.111240`

The goal is not to clone the authors' full codebase line by line, but to reproduce the hardware-side architecture and behavior closely enough to validate the paper's core claims:

- multi-stage parallel protocol-path recognition
- reduced T-CAM usage through graph partitioning results produced offline
- tenant-aware parsing support
- PHV generation for a downstream match-action pipeline

To simplify the work, this plan assumes the software/compiler side is replaced by manually prepared configuration tables at first. Hardware should accept those tables as inputs or preloaded ROM/RAM contents.

## 2. What The Paper Gives Us

The paper provides enough hardware-side guidance to reconstruct the top-level architecture:

- Packet header width used in evaluation: `2048 bits`
- Key-bit extraction width: up to `128 bits`
- Hardware is split into two major blocks:
  - `Protocol Features Recognizer`
  - `Protocol Keyword Extractor`
- Parsing graph partitioning is done offline in software
- Each sub-graph maps to one T-CAM stage or one lookup stage in a cascaded parser
- Multi-tenancy is supported by prepending tenant identity information such as:
  - `VLAN ID` (`12 bits`)
  - `VXLAN VNI` (`24 bits`)
- Output of the parser is a PHV-like extracted field vector for a downstream match-action pipeline

The paper does not fully specify every bitfield format, so this plan makes explicit engineering choices where needed.

## 3. Reproduction Scope

## 3.1 Minimal Reproduction

Reproduce the following:

- fixed-width packet header input of `2048 bits`
- configurable key-bit extraction
- at least `2` cascaded lookup stages
- action-table-driven field extraction
- PHV output
- optional tenant prefix support

This is enough to demonstrate the PParser idea.

## 3.2 Deferred Features

Leave these for later:

- full P4 frontend
- dynamic runtime reconfiguration protocol
- exact paper-matched evaluation graphs
- full deparser
- full downstream RMT match-action pipeline
- exact ASIC-oriented optimizations

## 4. Hardware Architecture To Reproduce

The hardware should be built as the following pipeline:

1. `Header Buffer`
2. `Tenant Identifier Extractor`
3. `Protocol Features Recognizer`
4. `Path Resolver`
5. `Protocol Keyword Extractor`
6. `PHV Builder`

### 4.1 Top-Level Dataflow

Input:

- packet header slice: `2048 bits`
- valid / ready handshake
- optional metadata: ingress port, packet length, tenant mode

Output:

- PHV
- parse-done
- parse-error
- protocol path ID
- tenant ID

Suggested logical flow:

1. Latch the first `2048 bits` of header
2. Extract tenant identity if enabled
3. Extract configured key bits for stage 0
4. Lookup stage 0 T-CAM or equivalent table
5. If more sub-graphs exist, repeat extract + lookup for later stages
6. Combine stage results into a final path/action index
7. Query action table
8. Extract configured header fields in groups
9. Emit PHV

## 5. Module-Level Plan

## 5.1 `pparser_top`

Responsibilities:

- top-level handshake
- instantiate all submodules
- route configuration memories
- track pipeline control

Suggested ports:

```verilog
module pparser_top #(
    parameter HEADER_W = 2048,
    parameter TENANT_W = 24,
    parameter KEY_W = 128,
    parameter PHV_W = 512,
    parameter NUM_STAGES = 2
) (
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  in_valid,
    output wire                  in_ready,
    input  wire [HEADER_W-1:0]   in_header,
    input  wire [15:0]           in_pkt_len,
    output wire                  out_valid,
    input  wire                  out_ready,
    output wire [PHV_W-1:0]      out_phv,
    output wire [TENANT_W-1:0]   out_tenant_id,
    output wire [15:0]           out_path_id,
    output wire                  out_parse_err
);
```

## 5.2 `header_buffer`

Responsibilities:

- latch the input header
- hold it stable while later pipeline stages operate

Implementation notes:

- for the first version, a single register bank is enough
- if timing is poor, split into `8 x 256-bit` or `16 x 128-bit` banks

## 5.3 `tenant_id_extractor`

Responsibilities:

- extract tenant identifier from configured bit positions
- support both VLAN and VXLAN mode

Simplified version:

- static configuration:
  - VLAN mode: extract 12 bits
  - VXLAN mode: extract 24 bits
- mode selected by a control register

Later version:

- configurable offset/bit selection just like key-bit extraction

Suggested outputs:

- `tenant_id`
- `tenant_valid`

## 5.4 `bit_extractor`

This is the most important block.

Responsibilities:

- extract arbitrary configured bits from the `2048-bit` header
- produce up to `128 bits` of packed key bits

Paper hint:

- upper 7 bits of instruction identify byte location
- lower 3 bits select a bit inside the byte

Recommended implementation:

- represent each extraction instruction as a byte index plus bit index
- one instruction per output key bit
- for `128` extracted bits, store `128` extraction descriptors

Suggested descriptor format:

```verilog
typedef struct packed {
    logic [7:0] byte_idx; // supports up to 256 bytes = 2048 bits
    logic [2:0] bit_idx;  // bit position inside byte
} key_sel_t;
```

Extraction rule:

```text
selected_bit = header[byte_idx * 8 + bit_idx]
```

Microarchitecture options:

- simple combinational extractor
- 2-stage pipelined extractor

Recommended first version:

- combinational gather for correctness
- add register after output

## 5.5 `protocol_features_recognizer`

Responsibilities:

- run one or more key-bit extraction passes
- feed extracted bits to lookup stages
- chain multi-subgraph parsing

Internal sub-blocks:

- stage configuration memory
- per-stage bit extractor
- per-stage lookup table
- stage result register

Per-stage configuration should include:

- number of valid key-bit descriptors
- extraction descriptor list
- lookup table selection
- next-stage enable

Suggested stage output:

- `stage_hit`
- `stage_path_fragment`
- `stage_action_fragment`
- `stage_done`

## 5.6 `lookup_stage`

Responsibilities:

- compare extracted key bits against preloaded entries
- produce matched entry index or action pointer

Important note:

True FPGA T-CAM is usually emulated with LUTs or BRAM-based structures. For reproduction, do not insist on a transistor-accurate T-CAM. Implement any deterministic ternary match engine with the same behavior.

Recommended first implementation:

- store entries in ROM or BRAM
- each entry contains:
  - `key_value`
  - `key_mask`
  - `path_fragment`
  - `action_fragment`

Match rule:

```text
hit when (input & mask) == (value & mask)
```

Suggested entry format:

```verilog
typedef struct packed {
    logic [127:0] key_value;
    logic [127:0] key_mask;
    logic [15:0]  path_fragment;
    logic [15:0]  action_fragment;
    logic         valid;
} tcam_entry_t;
```

Recommended capacities for first demo:

- stage 0: `32` entries
- stage 1: `128` entries

This mirrors the paper's `Big Union` example after partition.

## 5.7 `path_resolver`

Responsibilities:

- combine stage outputs into a final path ID
- decide whether parsing is complete

Simplified policy:

- concatenate or encode stage fragments
- final path ID is `stage0_fragment || stage1_fragment`

Alternative:

- each stage returns a direct pointer into a final action table

Recommended first version:

- use a direct action pointer from the last stage
- keep a debug path ID separately

## 5.8 `action_table`

Responsibilities:

- map tenant ID plus path result to extraction instructions

Paper idea:

- concatenate tenant identifier and key bits or lookup result to select extraction behavior

Practical reproduction:

- action-table address:
  - `tenant_id`
  - `path_id` or `action_fragment`

Suggested address format:

```text
action_addr = {tenant_id, action_id}
```

Action-table output should include:

- number of extraction groups
- per-group number of fields
- field offsets
- field widths
- destination PHV positions

## 5.9 `protocol_keyword_extractor`

Responsibilities:

- receive extraction instructions
- extract fields from the `2048-bit` header
- do grouped extraction to ease timing

Paper detail:

- instruction execution is grouped to avoid timing/resource problems when traversing the full header

Recommended reproduction:

- split extraction into `2` or `4` groups
- each cycle executes one group
- each group contains a small number of field operations

Suggested field descriptor:

```verilog
typedef struct packed {
    logic [10:0] src_lsb;   // 0..2047
    logic [7:0]  width;     // field width
    logic [8:0]  dst_lsb;   // position in PHV
    logic        valid;
} field_desc_t;
```

Field extraction rule:

```text
phv[dst_lsb +: width] = header[src_lsb +: width]
```

## 5.10 `phv_builder`

Responsibilities:

- assemble all extracted fields into one PHV register
- optionally append metadata such as tenant ID, path ID, parser flags

Recommended PHV width:

- `512 bits` for the first reproduction

If needed, define a structured PHV map:

- bits `[11:0]`: VLAN ID
- bits `[35:12]`: VNI or extended tenant field
- later regions: Ethernet, IPv4, IPv6, UDP, TCP fields

## 6. Configuration Memories

To simplify hardware reproduction, preload all configuration memories from hex files.

Required memories:

1. `tenant_cfg.mem`
- mode
- tenant extraction offsets

2. `stage0_keysel.mem`
- key-bit selection descriptors

3. `stage1_keysel.mem`
- second-stage descriptors

4. `stage0_tcam.mem`
- value, mask, action

5. `stage1_tcam.mem`
- value, mask, action

6. `action_table.mem`
- grouped field extraction descriptors

This lets you bypass the software compiler at first.

## 7. Suggested First Demo Protocol Set

Use a small but meaningful protocol graph:

- Ethernet
- VLAN
- MPLS
- IPv4
- IPv6
- TCP
- UDP
- VXLAN

Suggested example paths:

- `Eth -> IPv4 -> TCP`
- `Eth -> IPv4 -> UDP`
- `Eth -> VLAN -> IPv4 -> TCP`
- `Eth -> VLAN -> IPv4 -> UDP`
- `Eth -> IPv6 -> TCP`
- `Eth -> IPv6 -> UDP`
- `Eth -> MPLS -> IPv4 -> UDP`
- `Eth -> IPv4 -> UDP -> VXLAN -> Eth -> IPv4 -> TCP`

Then manually partition into two subgraphs:

- stage 0:
  - L2/L3 discrimination
  - `Eth / VLAN / MPLS / IPv4 / IPv6`
- stage 1:
  - L4/tunnel branch
  - `TCP / UDP / VXLAN / inner Eth / inner IPv4`

This is faithful to the paper's idea even if not identical to their exact evaluation graphs.

## 8. Pipeline Timing Plan

Recommended timing model for first hardware:

1. cycle 0:
   - latch header
   - extract tenant ID

2. cycle 1:
   - stage 0 key-bit extraction

3. cycle 2:
   - stage 0 lookup

4. cycle 3:
   - stage 1 key-bit extraction

5. cycle 4:
   - stage 1 lookup

6. cycle 5:
   - action-table read

7. cycle 6..N:
   - grouped field extraction

8. final cycle:
   - PHV valid

This is not required to match the paper's exact cycle counts, but it preserves the main property:

- later packets can enter before earlier ones fully finish if you pipeline the stages

## 9. Verification Strategy

## 9.1 Unit Tests

Write self-checking testbenches for:

- `bit_extractor`
- `lookup_stage`
- `tenant_id_extractor`
- `protocol_keyword_extractor`

Checks:

- arbitrary bit gather is correct
- ternary match behavior is correct
- tenant prefix extraction is correct
- field extraction writes the right PHV slices

## 9.2 Integration Tests

Build packet-header vectors for multiple protocol paths and tenants.

For each packet, verify:

- tenant ID
- stage 0 match
- stage 1 match
- final path ID
- action-table address
- extracted PHV fields

At minimum include:

- plain IPv4/TCP
- VLAN + IPv4/UDP
- IPv6/TCP
- VXLAN encapsulated inner IPv4/TCP
- two different tenants using different action tables

## 9.3 Stress Tests

Check:

- back-to-back packets
- packets from mixed tenants
- no-match behavior
- malformed header handling

Define parser error policies:

- `no_stage_hit`
- `ambiguous_match`
- `invalid_action_ptr`

## 10. FPGA Bring-Up Plan

### Phase 1: Simulation Only

- complete RTL
- preload simple `.mem` files
- verify all known paths in simulation

### Phase 2: Synthesis

- measure LUT/FF/BRAM
- identify whether lookup table emulation is LUT-heavy or BRAM-heavy

### Phase 3: On-Board Validation

- stream synthetic headers
- observe PHV outputs
- compare against software golden model

### Phase 4: Throughput Experiment

- feed packets every cycle or every few cycles
- measure initiation interval
- compare against a simplified FSM parser baseline

## 11. Baseline Comparison Plan

To support the paper's claims, build a simple FSM parser baseline:

- serial protocol identification
- one protocol decision per step
- field extraction after full path resolution

Compare against the staged parser on:

- cycles per packet
- initiation interval
- LUT usage
- BRAM usage

Even if your absolute numbers differ from the paper, the expected qualitative result should hold:

- staged parser improves throughput
- staged parser increases some memory or control complexity
- graph-partition-driven tables reduce path-table explosion

## 12. Engineering Assumptions

Because the paper omits some low-level formats, this reproduction plan adopts these assumptions:

- T-CAM is behaviorally reproduced using masked parallel compare
- action tables are ROM/BRAM backed
- field extraction descriptors are fixed width
- key extraction descriptors are explicit byte/bit selectors
- tenant-aware parsing uses `{tenant_id, action_id}` addressing
- PHV width is implementation-defined

These assumptions should be documented in any report so the reproduction is honest about what is exact and what is inferred.

## 13. Recommended File Structure

```text
pparser/
  rtl/
    pparser_top.v
    header_buffer.v
    tenant_id_extractor.v
    bit_extractor.v
    protocol_features_recognizer.v
    lookup_stage.v
    path_resolver.v
    action_table.v
    protocol_keyword_extractor.v
    phv_builder.v
  tb/
    tb_pparser_top.v
    tb_bit_extractor.v
    tb_lookup_stage.v
    tb_keyword_extractor.v
  mem/
    tenant_cfg.mem
    stage0_keysel.mem
    stage1_keysel.mem
    stage0_tcam.mem
    stage1_tcam.mem
    action_table.mem
  docs/
    pparser_hardware_reproduction_plan.md
```

## 14. Recommended Milestones

### Milestone A

Single-stage parser:

- one key extractor
- one lookup stage
- one action table
- one field extractor

### Milestone B

Two-stage cascaded parser:

- stage 0 + stage 1
- final path resolver

### Milestone C

Multi-tenant parser:

- VLAN mode
- VXLAN mode
- tenant-aware action addressing

### Milestone D

Performance-oriented cleanup:

- pipelining
- BRAM inference cleanup
- timing closure

## 15. What Counts As A Successful Reproduction

The reproduction should be considered successful if it demonstrates:

- the architecture split proposed by the paper
- offline-configured multi-stage path recognition
- reduced path-table growth through partitioned stages
- hardware field extraction into PHV
- tenant-aware parsing support
- a measurable throughput advantage over a simple FSM parser baseline

It does not need to exactly match every resource number in the paper to be academically useful.

## 16. Best Next Step

The best next implementation step is:

1. write a tiny golden software model that maps packets to:
   - tenant ID
   - stage 0 hit
   - stage 1 hit
   - final action
   - PHV
2. implement `bit_extractor`
3. implement `lookup_stage`
4. wire a two-stage `protocol_features_recognizer`
5. implement grouped `protocol_keyword_extractor`
6. validate everything in simulation before chasing FPGA numbers

