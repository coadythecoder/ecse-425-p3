# Processor testbench runner
quietly set LIB_NAME "work"

if {[file exists "$LIB_NAME"]} {
    vdel -lib "$LIB_NAME" -all
}
vlib "$LIB_NAME"
vmap work "$LIB_NAME"

vcom -2008 -work "$LIB_NAME" memory.vhd
vcom -2008 -work "$LIB_NAME" alu.vhd
vcom -2008 -work "$LIB_NAME" rf.vhd
vcom -2008 -work "$LIB_NAME" processor.vhd
vcom -2008 -work "$LIB_NAME" processor_tb.vhd

vsim -lib "$LIB_NAME" processor_tb
run -all
quit -f
