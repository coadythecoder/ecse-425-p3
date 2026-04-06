# run_sim.tcl
# ─────────────────────────────────────────────
# Setup
# ─────────────────────────────────────────────
quietly set SRC_DIR "."
quietly set LIB_NAME "work"

# Clean up any previous simulation
if {[file exists $LIB_NAME]} {
    vdel -lib $LIB_NAME -all
}
vlib $LIB_NAME
vmap work $LIB_NAME

# ─────────────────────────────────────────────
# Compile sources (order matters: dependencies first)
# ─────────────────────────────────────────────
vcom -2008 -work work "$SRC_DIR/memory.vhd"
vcom -2008 -work work "$SRC_DIR/cache.vhd"
vcom -2008 -work work "$SRC_DIR/cache_tb.vhd"

# ─────────────────────────────────────────────
# Simulate
# ─────────────────────────────────────────────
vsim -t 1ns -lib work cache_tb

# ─────────────────────────────────────────────
# Waveform setup (optional but very useful)
# ─────────────────────────────────────────────
add wave -divider "Clock / Reset"
add wave -radix binary    sim:/cache_tb/clk
add wave -radix binary    sim:/cache_tb/reset

add wave -divider "Slave (CPU-side)"
add wave -radix hex       sim:/cache_tb/s_addr
add wave -radix binary    sim:/cache_tb/s_read
add wave -radix binary    sim:/cache_tb/s_write
add wave -radix hex       sim:/cache_tb/s_readdata
add wave -radix hex       sim:/cache_tb/s_writedata
add wave -radix binary    sim:/cache_tb/s_waitrequest

add wave -divider "Master (Memory-side)"
add wave -radix unsigned  sim:/cache_tb/m_addr
add wave -radix binary    sim:/cache_tb/m_read
add wave -radix binary    sim:/cache_tb/m_write
add wave -radix hex       sim:/cache_tb/m_readdata
add wave -radix hex       sim:/cache_tb/m_writedata
add wave -radix binary    sim:/cache_tb/m_waitrequest

# ─────────────────────────────────────────────
# Run
# ─────────────────────────────────────────────
run -all

# Zoom waveform to fit all recorded time
wave zoom full
