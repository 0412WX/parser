# PParser Verilog Rebuild

This directory contains a Vivado-friendly RTL rebuild of the staged Python parser model.
The current version follows a strict subgraph-cascade flow: every packet traverses both lookup subgraphs and exits through a single final resolver.

## Layout

- `rtl/`: parser RTL modules
- `tb/`: self-checking testbench
- `xdc/`: minimal clock constraint
- `scripts/create_project.tcl`: recreate the Vivado project
- `scripts/open_wave_gui.tcl`: open the project and launch behavioral simulation with useful waves
- `scripts/run_batch_sim.ps1`: run `xvlog/xelab/xsim` in batch mode
- `scripts/run_synth.tcl`: run synthesis and emit utilization/timing reports
- `scripts/open_synth_gui.tcl`: open synthesized design with reports

## Expected Simulation Result

The testbench sends:

- 8 valid protocol paths
- 1 invalid packet
- 100 back-to-back packets

The expected result is:

- all valid packets decode to the correct `path_id`
- the invalid packet reports `path_id = 4'hF` with `out_error = 1`
- fixed pipeline latency of 7 cycles in the nominal burst
- initiation interval of 1 cycle for the burst
- additional backpressure coverage verifies no reordering, no drops, and no latency underflow

## Reports

- Batch simulation: `scripts/run_batch_sim.ps1`
- Synthesis for the paper target part: `scripts/run_synth.tcl`
- Synthesis for a license-friendly 7-series device: `scripts/run_synth_generic_7series.tcl`
- Generated reports and checkpoints are written under `reports/`
  - `pparser_utilization_synth_generic_7series.rpt`
  - `pparser_timing_summary_synth_generic_7series.rpt`
  - `pparser_high_fanout_synth_generic_7series.rpt`
  - `pparser_synth_generic_7series.dcp`

## Subgraph Cascade

- `Stage0` recognizes the top-level protocol class from `EtherType`
- `Stage1` always runs, even for short paths
- short paths use a `bypass` entry in the second subgraph
- `pparser_final_resolver` combines `stage0` and `stage1` results at a single exit point
