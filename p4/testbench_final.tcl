vlib work
vmap work work

# Compile all sources
vcom -2008 intermediate_reg.vhd
vcom -2008 memory.vhd
vcom -2008 rf.vhd
vcom -2008 alu.vhd
vcom -2008 processor_pip.vhd

vsim work.processor_pip

set imem_path "/processor_pip/instr_mem/ram_block"
set dmem_path "/processor_pip/data_mem/ram_block"
set rf_path   "/processor_pip/reg_file/my_rf"

set program_file "program.txt"
if {![file exists $program_file]} {
    echo "ERROR: $program_file not found"
    quit -code 1 -f
}

set fp [open $program_file r]
set idx 0
while {[gets $fp line] >= 0} {
    set line [string trim $line]
    if {$line eq ""} {
        continue
    }
    if {[regexp {^#} $line]} {
        continue
    }

    if {[regexp {^[01]{32}$} $line]} {
        force -deposit "$imem_path\($idx\)" 2#$line 0
        incr idx
    } elseif {[regexp {^[0-9A-Fa-f]{8}$} $line]} {
        force -deposit "$imem_path\($idx\)" 16#$line 0
        incr idx
    } else {
        echo "WARNING: skipping malformed program line: $line"
    }

    if {$idx > 1024} {
        echo "ERROR: program exceeds 1024 instructions"
        close $fp
        quit -code 1 -f
    }
}
close $fp

# 1 GHz clock (1 ns period), reset, then run 10,000 cycles.
force /processor_pip/clock 0 0ns, 1 0.5ns -repeat 1ns
force /processor_pip/reset 1 0ns
run 2ns
force /processor_pip/reset 0 0ns
run 10000ns

set rf_out [open "register_file.txt" w]
for {set i 0} {$i < 32} {incr i} {
    set val [string trim [examine -radix binary "$rf_path\($i\)"]]
    puts $rf_out $val
}
close $rf_out

set mem_out [open "memory.txt" w]
for {set i 0} {$i < 8192} {incr i} {
    set val [string trim [examine -radix binary "$dmem_path\($i\)"]]
    puts $mem_out $val
}
close $mem_out

quit -f
