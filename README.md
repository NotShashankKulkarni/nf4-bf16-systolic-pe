# NF4 x BF16 Weight-Stationary Systolic PE

Verilog implementation and evaluation of two weight-stationary processing
elements (PEs) for a systolic-array AI accelerator:

- **Baseline:** BF16 x BF16 PE with a 16-bit stationary weight register
  and a conventional significand multiplier.
- **Proposed:** NF4 x BF16 PE with a 4-bit stationary NF4 code register
  and a shared shift-and-add significand network (5 slots, 4-adder
  combine tree, per-slot operand isolation).

Both share the same FP32 accumulator and pipeline. A paper describing
this work is in preparation.

## Results (OpenROAD `report_power`, sky130_fd_sc_hd, tt_025C_1v80)

| | Baseline | Proposed |
|---|---|---|
| Total power | 6.90 mW | 5.97 mW (**-13.5%**) |
| Sequential internal power | 6.04 mW | 5.05 mW |
| Combinational switching power | 0.491 mW | 0.535 mW |

Raw reports are in [`results/`](results/).

**What this means, stated plainly:**

- The 13.5% saving comes from the **narrower stationary register**
  (4-bit NF4 code vs 16-bit BF16 weight), which lowers sequential power.
- The shift-and-add network's intended **switching-power reduction did
  not materialize**: combinational switching power rose slightly.
- In our synthesis runs, an operand-isolated multiplier and an
  un-isolated "compute all 16 branches, then select" multiplier gave an
  identical cell histogram. Logic synthesis recognized them as
  functionally equivalent and optimized both to the same netlist.
  RTL-level operand isolation alone is therefore not guaranteed to
  survive synthesis.
- The OpenROAD numbers above were measured on the un-isolated variant of
  the multiplier RTL. The isolated version in `rtl/` produced an
  identical multiplier cell histogram, so the power result is expected to
  be the same, but it was not re-run through OpenROAD.

## Verification

- Exhaustive: all 16 NF4 codes x all 65,536 BF16 bit patterns
  (1,048,576 vectors), zero mismatches against a floating-point
  reference.
- System level: both PEs driven with identical inputs and compared every
  cycle under three regimes (weight changing every cycle, weight
  stationary, and a workload built by quantizing Gaussian samples in
  64-element blocks). Zero mismatches.

## Layout

```
rtl/        pe_baseline_bf16.v  (baseline PE + shared FP32 adder helpers)
            pe_optimized_nf4.v  (NF4 multiplier + PE; needs the file above)
tb/         testbench.v, tb_nf4_mul_fp32.v, representative_codes.hex
synth/      Yosys scripts (sky130)
openroad/   OpenROAD Tcl scripts (stop after global_route, then report_power)
results/    report_power outputs
```

`pe_optimized_nf4.v` reuses modules defined in `pe_baseline_bf16.v`
(`fp32_add`, `lzc27`, `rshift_sticky`), so both files must always be
compiled together, baseline first.

## Run

Simulation (Icarus Verilog), from `tb/`:

```bash
iverilog -g2012 -o sim.vvp ../rtl/pe_baseline_bf16.v ../rtl/pe_optimized_nf4.v testbench.v
vvp sim.vvp        # expect: ALL PE OUTPUTS IDENTICAL ACROSS ALL REGIMES - PASS

iverilog -g2012 -o ex.vvp ../rtl/pe_baseline_bf16.v ../rtl/pe_optimized_nf4.v tb_nf4_mul_fp32.v
vvp ex.vvp         # expect: 1048576 vectors, 0 failures
```

Synthesis (Yosys), from `synth/`. The scripts expect the sky130 Liberty
file in the working directory:

```bash
ln -s ~/.volare/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib .
yosys synth_baseline.ys
yosys synth_optimized.ys
```

Place and route (OpenROAD), from `openroad/` (needs the `_syn.v`
netlists from the Yosys step; the scripts assume the PDK at
`~/.volare/sky130A`):

```bash
openroad run_baseline.tcl
openroad run_optimized.tcl
```

Note: the path changes made when organizing this repository were checked
for simulation but the Yosys and OpenROAD scripts were not re-run after
the change. If a path fails, adjust it for your setup.

## Requirements

Icarus Verilog (`-g2012`), Yosys 0.33, OpenROAD, and the SkyWater sky130
PDK (installed e.g. via `volare`).

## Known limitations

- One process corner (typical, 25 C, 1.8 V); no multi-corner signoff.
- Global routing only; no detailed routing or parasitic extraction.
- No timing / critical-path comparison yet.
- Single PE, not a tiled array.
- Evaluation weights are synthetic (Gaussian, quantized to NF4), not from
  a pretrained model.

## References

- Dettmers et al., *QLoRA: Efficient Finetuning of Quantized LLMs*, NeurIPS 2023.
- Zhang et al., *MixPE: Quantization and Hardware Co-design for Efficient LLM Inference*, 2024.
- Jouppi et al., *In-Datacenter Performance Analysis of a Tensor Processing Unit*, ISCA 2017.

## License

Apache-2.0. See [LICENSE](LICENSE).
