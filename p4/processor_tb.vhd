library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

entity processor_tb is
end processor_tb;

architecture behavior of processor_tb is
    component processor is
        port(
            clock  : in std_logic;
            reset  : in std_logic
        );
    end component;

    signal clock : std_logic := '0';
    signal reset : std_logic := '1';

    constant clk_period : time := 10 ns;

    type mem_type is array(32767 downto 0) of std_logic_vector(31 downto 0);

    alias pc_value : integer is
        << signal .processor_tb.dut.pc : integer >>;
    alias instr_ram : mem_type is
        << signal .processor_tb.dut.instr_mem.ram_block : mem_type >>;
begin
    dut: processor port map(
        clock => clock,
        reset => reset
    );

    clock_process: process
    begin
        while true loop
            clock <= '0';
            wait for clk_period / 2;
            clock <= '1';
            wait for clk_period / 2;
        end loop;
    end process;

    test_process: process
        procedure load_program(constant file_name : in string) is
            file prog_file : text open read_mode is file_name;
            variable line_buf : line;
            variable word_buf : std_logic_vector(31 downto 0);
            variable good : boolean;
            variable idx : integer := 0;
        begin
            while not endfile(prog_file) loop
                readline(prog_file, line_buf);
                hread(line_buf, word_buf, good);
                if good then
                    instr_ram(idx) <= word_buf;
                    idx := idx + 1;
                end if;
            end loop;
        end procedure;
    begin
        report "Processor tests start";

        wait for 1 ns;
        load_program("program.txt");
        wait for 1 ns;

        reset <= '1';
        wait for 3 * clk_period;
        wait until rising_edge(clock);
        reset <= '0';

        for i in 0 to 9999 loop
            wait until rising_edge(clock);

            -- FETCH of SRL (PC=32): pc was set by SLL WRITEBACK one cycle earlier.
            -- Verifies 8 sequential arithmetic instructions (ADDI x2, ADD, SUB,
            -- MUL, AND, OR, SLL) all executed correctly.
            if i = 40 then
                assert pc_value = 32
                    report "Expected PC=32 after 8 sequential arithmetic instructions"
                    severity error;
            end if;

            -- FETCH of BNE (PC=56): pc was set by BEQ WRITEBACK one cycle earlier.
            -- BEQ (PC=48) compared x11==x10==7 and jumped to PC+8=56 (taken).
            -- If not taken, pc would be 52.
            if i = 65 then
                assert pc_value = 56
                    report "Expected PC=56: BEQ (x11=x10=7) should have been taken"
                    severity error;
            end if;

            -- First JAL WRITEBACK (PC=64): pc was set by ADDI x13 WRITEBACK one
            -- cycle earlier (ADDI x13 at PC=60 → pc=64), confirming BNE was NOT
            -- taken and ADDI x13 executed.  JAL now loops at PC=64.
            if i = 79 then
                assert pc_value = 64
                    report "Expected PC=64: BNE not taken + JAL loop at PC=64"
                    severity error;
            end if;
        end loop;

        report "Processor tests complete";
        std.env.stop;
        wait;
    end process;
end behavior;
