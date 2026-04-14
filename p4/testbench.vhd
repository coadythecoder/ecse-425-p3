-- =============================================================================
-- testbench.vhd  --  Basic functional test for processor_pip
-- =============================================================================
-- Program loaded directly into instruction memory (no program.txt).
--
-- Test sequence (each instruction encoded as a 32-bit RISC-V word):
--
--  [0]  addi x1, x0, 5        -- x1 = 5
--  [1]  addi x2, x0, 3        -- x2 = 3
--  [2]  add  x3, x1, x2       -- x3 = 8
--  [3]  sub  x4, x1, x2       -- x4 = 2
--  [4]  addi x5, x0, 10       -- x5 = 10  (store value)
--  [5]  sw   x5, 0(x0)        -- mem[0] = 10
--  [6]  lw   x6, 0(x0)        -- x6 = mem[0] = 10
--  [7]  beq  x1, x1, +8       -- branch taken  (skip [8], land on [9])
--  [8]  addi x7, x0, 99       -- should be skipped
--  [9]  addi x8, x0, 42       -- x8 = 42  (confirms branch was taken)
--
-- Checks performed (after enough cycles for the pipeline to drain):
--   x1  = 5
--   x2  = 3
--   x3  = 8
--   x4  = 2
--   x6  = 10   (load from data memory)
--   x7  = 0    (branch skipped the addi)
--   x8  = 42   (branch was taken)
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity testbench is
end testbench;

architecture sim of testbench is

    -- -------------------------------------------------------------------------
    -- DUT
    -- -------------------------------------------------------------------------
    component processor_pip is
        port(
            clock : in std_logic;
            reset : in std_logic
        );
    end component;

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    constant CLK_PERIOD : time := 1 ns;   -- 1 GHz

    -- -------------------------------------------------------------------------
    -- Instruction encodings  (hand-assembled RISC-V RV32I)
    -- -------------------------------------------------------------------------
    --  addi rd, rs1, imm  =>  imm[11:0] | rs1 | 000 | rd | 0010011
    --  add  rd, rs1, rs2  =>  0000000 | rs2 | rs1 | 000 | rd | 0110011
    --  sub  rd, rs1, rs2  =>  0100000 | rs2 | rs1 | 000 | rd | 0110011
    --  sw   rs2, imm(rs1) =>  imm[11:5] | rs2 | rs1 | 010 | imm[4:0] | 0100011
    --  lw   rd, imm(rs1)  =>  imm[11:0] | rs1 | 010 | rd | 0000011
    --  beq  rs1,rs2,imm   =>  imm[12|10:5] | rs2 | rs1 | 000 | imm[4:1|11] | 1100011

    -- addi x1, x0, 5   =>  000000000101 | 00000 | 000 | 00001 | 0010011
    constant ADDI_X1_5   : std_logic_vector(31 downto 0) := x"00500093";

    -- addi x2, x0, 3   =>  000000000011 | 00000 | 000 | 00010 | 0010011
    constant ADDI_X2_3   : std_logic_vector(31 downto 0) := x"00300113";

    -- add x3, x1, x2   =>  0000000 | 00010 | 00001 | 000 | 00011 | 0110011
    constant ADD_X3      : std_logic_vector(31 downto 0) := x"002081B3";

    -- sub x4, x1, x2   =>  0100000 | 00010 | 00001 | 000 | 00100 | 0110011
    constant SUB_X4      : std_logic_vector(31 downto 0) := x"40208233";

    -- addi x5, x0, 10  =>  000000001010 | 00000 | 000 | 00101 | 0010011
    constant ADDI_X5_10  : std_logic_vector(31 downto 0) := x"00A00293";

    -- sw x5, 0(x0)     =>  0000000 | 00101 | 00000 | 010 | 00000 | 0100011
    constant SW_X5       : std_logic_vector(31 downto 0) := x"00502023";

    -- lw x6, 0(x0)     =>  000000000000 | 00000 | 010 | 00110 | 0000011
    constant LW_X6       : std_logic_vector(31 downto 0) := x"00002303";

    -- beq x1, x1, +8   =>  offset = 8 => imm = 0x008
    --   imm[12]=0, imm[10:5]=000000, imm[4:1]=0100, imm[11]=0
    --   => 0000000 | 00001 | 00001 | 000 | 01000 | 1100011
    --   Encoding: {0,000000,00001,00001,000,0100,0,1100011}
    constant BEQ_TAKEN   : std_logic_vector(31 downto 0) := x"00108463";

    -- addi x7, x0, 99  (should be skipped by beq)
    constant ADDI_X7_99  : std_logic_vector(31 downto 0) := x"06300393";

    -- addi x8, x0, 42
    constant ADDI_X8_42  : std_logic_vector(31 downto 0) := x"02A00413";

    -- -------------------------------------------------------------------------
    -- Program array (14 instructions)
    -- -------------------------------------------------------------------------
    type prog_t is array (0 to 9) of std_logic_vector(31 downto 0);
    constant PROGRAM : prog_t := (
        ADDI_X1_5,    -- [0]
        ADDI_X2_3,    -- [1]
        ADD_X3,       -- [2]
        SUB_X4,       -- [3]
        ADDI_X5_10,   -- [4]
        SW_X5,        -- [5]
        LW_X6,        -- [6]
        BEQ_TAKEN,    -- [7]
        ADDI_X7_99,   -- [8]  skipped
        ADDI_X8_42   -- [9]
    );

    -- -------------------------------------------------------------------------
    -- Aliases into DUT internals (ModelSim allows reading internal signals)
    -- -------------------------------------------------------------------------
    -- These use signal aliasing; in ModelSim you can also just use
    -- <</testbench/uut/reg_file/registers(N)>> extended names.
    -- Adjust paths if your rf.vhd uses a different array name.

    type reg_array_t is array (31 downto 0) of std_logic_vector(31 downto 0);
    alias regs : reg_array_t is << signal .testbench.uut.reg_file.my_rf : reg_array_t >>;

begin

    -- -------------------------------------------------------------------------
    -- Instantiate DUT
    -- -------------------------------------------------------------------------
    uut : processor_pip
        port map(
            clock => clk,
            reset => rst
        );

    -- -------------------------------------------------------------------------
    -- Clock
    -- -------------------------------------------------------------------------
    clk <= not clk after CLK_PERIOD / 2;

    -- -------------------------------------------------------------------------
    -- Stimulus
    -- -------------------------------------------------------------------------
    stim : process
        -- Convenience: wait N rising edges
        procedure tick(n : positive := 1) is
        begin
            for i in 1 to n loop
                wait until rising_edge(clk);
            end loop;
        end procedure;

        -- Simple assertion helper
        procedure check(
            signal_name : string;
            got         : std_logic_vector(31 downto 0);
            expected    : integer
        ) is
            variable exp_slv : std_logic_vector(31 downto 0);
        begin
            exp_slv := std_logic_vector(to_signed(expected, 32));
            if got = exp_slv then
                report "[PASS] " & signal_name & " = " & integer'image(expected)
                    severity warning;
            else
                report "[FAIL] " & signal_name &
                    " expected " & integer'image(expected) &
                    " got "      & integer'image(to_integer(signed(got)))
                    severity error;
            end if;
        end procedure;

    begin
        -- --------------------------------------------------------------------
        -- 1. Hold reset, load program into instruction memory
        --    The memory component's internal RAM is pre-loaded here using
        --    ModelSim signal-force before time advances.
        --    (In VHDL simulation the initial content of the RAM must be set
        --     via the memory component's init file or by the Tcl layer.
        --     This testbench calls mem load from the companion Tcl script
        --     testbench.tcl which sources this VHDL and pre-loads the RAM.)
        -- --------------------------------------------------------------------
        rst <= '1';
        wait for 5 * CLK_PERIOD;
        rst <= '0';
        wait for 5 * CLK_PERIOD;

        -- --------------------------------------------------------------------
        -- 2. Run enough cycles for the 14-instruction program to fully drain
        --    through the 5-stage pipeline (14 instr + 4 pipeline stages +
        --    branch/load penalties + margin = 50 cycles is generous)
        -- --------------------------------------------------------------------
	report "Before tick" severity warning;
        tick(50);

        -- --------------------------------------------------------------------
        -- 3. Check register file
        --    Access via ModelSim external name syntax:
        --      << signal /testbench/uut/reg_file/registers(N) : std_logic_vector >>
        --    If your rf.vhd uses a different internal name, update accordingly.
        -- --------------------------------------------------------------------
	report "Reached check section" severity warning;
	check("x1", regs(1), 5);
	check("x2", regs(2), 3);
	check("x3", regs(3), 8);
	check("x4", regs(4), 2);
	check("x6", regs(6), 10);
	check("x7", regs(7), 0);
	check("x8", regs(8), 42);        report "--- Testbench complete ---" severity note;
        wait;
    end process;

end sim;
