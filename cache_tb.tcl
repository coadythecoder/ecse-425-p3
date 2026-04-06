# run_sim.tcl
# ─────────────────────────────────────────────
# Setup
# ─────────────────────────────────────────────
quietly set SRC_DIR "P:/425p3/ecse-425-p3"
quietly set LIB_NAME "work"

# Clean up any previous simulation
if {[file exists "$SRC_DIR/$LIB_NAME"]} {
    vdel -lib "$SRC_DIR/$LIB_NAME" -all
}
vlib "$SRC_DIR/$LIB_NAME"
vmap work "$SRC_DIR/$LIB_NAME"

# ─────────────────────────────────────────────
# Compile sources (order matters: dependencies first)
# ─────────────────────────────────────────────
vcom -2008 -work "$SRC_DIR/$LIB_NAME" "$SRC_DIR/memory.vhd"
vcom -2008 -work "$SRC_DIR/$LIB_NAME" "$SRC_DIR/cache.vhd"
vcom -2008 -work "$SRC_DIR/$LIB_NAME" "$SRC_DIR/cache_tb.vhd"

# ─────────────────────────────────────────────
# Simulate
# ─────────────────────────────────────────────
vsim -lib "$SRC_DIR/$LIB_NAME" cache_tb

# ─────────────────────────────────────────────
# Waveform setup
# ─────────────────────────────────────────────
add wave -divider "Clock / Reset"
add wave -radix binary   /cache_tb/clk
add wave -radix binary   /cache_tb/reset

add wave -divider "Slave (CPU-side)"
add wave -radix hex      /cache_tb/s_addr
add wave -radix binary   /cache_tb/s_read
add wave -radix binary   /cache_tb/s_write
add wave -radix hex      /cache_tb/s_readdata
add wave -radix hex      /cache_tb/s_writedata
add wave -radix binary   /cache_tb/s_waitrequest

add wave -divider "Master (Memory-side)"
add wave -radix unsigned /cache_tb/m_addr
add wave -radix binary   /cache_tb/m_read
add wave -radix binary   /cache_tb/m_write
add wave -radix hex      /cache_tb/m_readdata
add wave -radix hex      /cache_tb/m_writedata
add wave -radix binary   /cache_tb/m_waitrequest

# ─────────────────────────────────────────────
# Run
# ─────────────────────────────────────────────
run -all
wave zoom full