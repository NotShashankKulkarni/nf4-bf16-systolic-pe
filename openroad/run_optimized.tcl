# --- 1. SETUP PDK & DESIGN ---
set pdk_root "$::env(HOME)/.volare/sky130A"
read_lef $pdk_root/libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd__nom.tlef
read_lef $pdk_root/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef
read_liberty $pdk_root/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# optimized PE -- read the SYNTHESIZED netlist (from synth_optimized.ys),
# not the raw RTL. OpenROAD does not synthesize; run Yosys first.
read_verilog ../synth/pe_optimized_syn.v
link_design pe_nf4_bf16_ws

# --- 2. FLOORPLAN ---
initialize_floorplan -die_area "0 0 220 220" -core_area "5 5 215 215" -site unithd

# --- 3. TRACKS (must come before place_pins) ---
make_tracks

# --- 4. PIN PLACEMENT ---
place_pins -hor_layers met3 -ver_layers met2

# --- 5. PLACEMENT ---
global_placement
detailed_placement

# --- 6. ROUTING SETUP ---
global_route

# Note: script stops here, same as your original -- continue manually
# in the OpenROAD prompt from this point (detailed_route, etc.)
report_power
