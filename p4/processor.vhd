library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity processor is
    port(
        clock  : in std_logic;
        reset  : in std_logic
    );
end processor;

architecture arch of processor is
    component memory is
        generic(
            ram_size : integer := 32768;
            mem_delay : time := 1 ns;
            clock_period : time := 1 ns;
            writable : boolean := true
        );
        port (
            clock: in std_logic;
            writedata: in std_logic_vector(31 downto 0);
            address: in integer range 0 to ram_size-1;
            memwrite: in std_logic;
            memread: in std_Logic;
            readdata: out std_logic_vector(31 downto 0);
            waitrequest: out std_logic
        );
    end component;
    
    component rf is 
        port(
            clk : in std_logic;
            reset : in std_logic;
            read_addr1 : in std_logic_vector(4 downto 0);
            read_addr2 : in std_logic_vector(4 downto 0);
            write_addr : in std_logic_vector(4 downto 0);
            write_data : in std_logic_vector(31 downto 0);
            write_enable : in std_logic;
            read_data1 : out std_logic_vector(31 downto 0);
            read_data2 : out std_logic_vector(31 downto 0)
        );
    end component;

    component alu is
        port (
            instruction : in std_logic_vector(31 downto 0);
            op1 : in std_logic_vector(31 downto 0);
            op2 : in std_logic_vector(31 downto 0);
            result : out std_logic_vector(31 downto 0)
        );
    end component;

    component if_id_reg is
        port (
            clk        : in  std_logic;
            reset      : in  std_logic;
            enable     : in  std_logic;
            ir_in   : in  std_logic_vector(31 downto 0);
            pc_in      : in  std_logic_vector(31 downto 0);
            ir_out  : out std_logic_vector(31 downto 0);
            pc_out     : out std_logic_vector(31 downto 0)
        );
    end component;

    component id_ex_reg is
        port (
            clk	: in  std_logic;
            reset	: in  std_logic;
            enable	: in  std_logic;
            npc_in	: in  std_logic_vector(31 downto 0);
            a_in	: in  std_logic_vector(31 downto 0);
            b_in	: in  std_logic_vector(31 downto 0);
            immval_in	: in  std_logic_vector(31 downto 0);
            rd_in	: in  std_logic_vector(11 downto 7);
            ir_in   : in  std_logic_vector(31 downto 0);
            mux_a_select_in   : in  std_logic;
            mux_b_select_in   : in  std_logic;
            npc_out	: out  std_logic_vector(31 downto 0);
            a_out	: out  std_logic_vector(31 downto 0);
            b_out	: out  std_logic_vector(31 downto 0);
            immval_out	: out  std_logic_vector(31 downto 0);
            rd_out	: out  std_logic_vector(11 downto 7);
            ir_out  : out std_logic_vector(31 downto 0);
            mux_a_select_out   : out  std_logic;
            mux_b_select_out   : out  std_logic;
        );
    end component;

    component ex_mem_reg is 
        port (
            clk	: in  std_logic;
            reset	: in  std_logic;
            enable	: in  std_logic;
            mux_pc_select_in	: in  std_logic;
            aluout_in	: in  std_logic_vector(31 downto 0);
            b_in	: in  std_logic_vector(31 downto 0);
            rd_in	: in  std_logic_vector(11 downto 7);
            ir_in   : in  std_logic_vector(31 downto 0);
            mux_pc_select_out	: out  std_logic;
            aluout_out	: out  std_logic_vector(31 downto 0);
            b_out	: out  std_logic_vector(31 downto 0);
            rd_out	: out  std_logic_vector(11 downto 7);
            ir_out   : out  std_logic_vector(31 downto 0)
        );
    end component;

    component mem_wb_reg is
        port (
            clk	: in  std_logic;
            reset	: in  std_logic;
            enable	: in  std_logic;
            regwrite_in	: in  std_logic;
            mux_write_select_in	: in  std_logic;
            aluout_in	: in  std_logic_vector(31 downto 0);
            mem_ldr_result_in	: in  std_logic_vector(31 downto 0);
            rd_in	: in  std_logic_vector(11 downto 7);
            regwrite_out	: out  std_logic;
            mux_write_select_out	: out  std_logic;
            aluout_out	: out  std_logic_vector(31 downto 0);
            mem_ldr_result_out	: out  std_logic_vector(31 downto 0);
            rd_out	: out  std_logic_vector(11 downto 7)
        );
    end component;

    signal pc : integer := 0;           -- program counter
    signal npc : integer := 0;          -- new program counter value (pc + 4)
    signal pc_word : integer := 0;      -- pc / 4 (word index for instruction memory)
    signal ir : std_logic_vector(31 downto 0);  -- instruction register, used to hold Mem[PC]
    signal A : std_logic_vector(31 downto 0);   -- register to store read data 1
    signal B : std_logic_vector(31 downto 0);   -- register to store reaad data 2
    signal imm : std_logic_vector(31 downto 0); -- extended (be careful) immediate value
    signal lmd : std_logic_vector(31 downto 0); -- register to store data loaded from memory
    signal alu_out : std_logic_vector(31 downto 0); -- register to store output of alu
    signal alu_out_int : integer := 0;
    signal data_addr : integer := 0;    -- alu_out_int / 4 (word index for data memory)

    signal mux_a : std_logic_vector(31 downto 0); -- mux for input 1 of alu
    signal mux_b : std_logic_vector(31 downto 0); -- mux for input 2 of alu
    signal mux_pc : std_logic_vector(31 downto 0); -- mux for updating pc value
    signal mux_write : std_logic_vector(31 downto 0); -- mux for writeback

    signal mem_read  : std_logic := '0'; -- selector to read from data memory
    signal mem_write : std_logic := '0'; -- selector to write to data memory
    signal reg_write : std_logic := '0'; -- selector to write to registers

    -- mux_a_select: '0' => A (rs1), '1' => pc
    signal mux_a_select : std_logic := '0';     -- selector for mux_a
    -- mux_b_select: '0' => imm, '1' => B (rs2) 
    signal mux_b_select : std_logic := '0';     -- selector for mux_b
    -- mux_pc_select: '0' => alu_out (branch/jump target), '1' => npc (sequential)
    signal mux_pc_select : std_logic := '1';        -- selector for mux_pc
    -- mux_write_select: 0 => alu_out, 1 => lmd, 2 => npc (return address)
    signal mux_write_select : integer range 0 to 2 := 0; -- selector for mux_write

    type state_type is (FETCH, DECODE, EXECUTE, MEM, WRITEBACK);
    signal state : state_type := FETCH;

begin
    -- Combinatorial conversions
    alu_out_int <= to_integer(signed(alu_out));
    data_addr   <= alu_out_int / 4 when alu_out_int >= 0 else 0; -- prevent overflow
    pc_word     <= pc / 4;

    -- Muxes combinatorial
    -- mux_a: '0' => rs1 register, '1' => current PC (for branch/JAL targets)
    mux_a <= A when mux_a_select = '0' else std_logic_vector(to_unsigned(pc, 32));
    -- mux_b: '0' => immediate, '1' => rs2 register
    mux_b <= imm when mux_b_select = '0' else B;
    -- mux_pc: '0' => alu_out (branch/jump target), '1' => npc (fall-through)
    mux_pc <= alu_out when mux_pc_select = '0' else std_logic_vector(to_unsigned(npc, 32));
    -- mux_write: 0 => alu_out, 1 => lmd (loaded value), 2 => npc (JAL return addr)
    mux_write <= alu_out when mux_write_select = 0
            else lmd    when mux_write_select = 1
            else std_logic_vector(to_unsigned(npc, 32));

    -- Data memory (byte-addressed in RISC-V; word-indexed here via data_addr = alu_out/4)
    data_mem : memory port map(
        clock => clock,
        writedata => B,
        address => data_addr,
        memwrite => mem_write,
        memread => mem_read,
        readdata => lmd,
        waitrequest => open
    );

    -- Instruction memory (word-indexed via pc_word = pc/4)
    instr_mem : memory
        generic map(writable => false)
        port map(
            clock => clock,
            writedata => (others => '0'),
            address => pc_word,
            memwrite => '0',
            memread => '0',
            readdata => ir,
            waitrequest => open
        );

    -- Register file
    reg_file : rf port map(
        clk => clock,
        reset => reset,
        read_addr1 => ir(19 downto 15),
        read_addr2 => ir(24 downto 20),
        write_addr => ir(11 downto 7),
        write_data => mux_write,
        write_enable => reg_write,
        read_data1 => A,
        read_data2 => B
    );

    -- ALU
    my_alu : alu port map(
        instruction => ir,
        op1 => mux_a,
        op2 => mux_b,
        result => alu_out
    );

    cpu_process: process(clock, reset)
        variable opcode : std_logic_vector(6 downto 0);
        variable funct3 : std_logic_vector(3 downto 0);
        variable imm_raw : std_logic_vector(31 downto 0);
    begin
        if reset = '1' then
            pc <= 0;
            state <= FETCH;
            mem_write <= '0';
            mem_read <= '0';
            reg_write <= '0';
            mux_pc_select <= '1';

        elsif rising_edge(clock) then
            case state is
                -- FETCH: latch npc; memory samples pc_word this cycle and
                --        ir (readdata) will be valid in DECODE.
                when FETCH =>
                    reg_write <= '0';
                    npc <= pc + 4;
                    state <= DECODE;
                -- DECODE: ir is now valid. Extract opcode, build immediate,
                --         set mux selects.
                when DECODE =>
                    opcode  := ir(6 downto 0);
                    imm_raw := (others => '0');

                    case opcode is
                        when "0110011" => -- R-type
                            mux_a_select <= '0'; -- op1 = rs1
                            mux_b_select <= '1'; -- op2 = rs2 (register B)

                        when "0010011" | "0000011" | "1100111" => -- I-type ALU / load / JALR
                            imm_raw(11 downto 0) := ir(31 downto 20);
                            -- sign-extend from bit 11
                            if ir(31) = '1' then
                                imm_raw(31 downto 12) := (others => '1');
                            end if;
                            mux_a_select <= '0'; -- op1 = rs1
                            mux_b_select <= '0'; -- op2 = imm

                        when "0100011" => -- S-type (store)
                            imm_raw(11 downto 5) := ir(31 downto 25);
                            imm_raw(4  downto 0) := ir(11 downto 7);
                            if ir(31) = '1' then
                                imm_raw(31 downto 12) := (others => '1');
                            end if;
                            mux_a_select <= '0'; -- op1 = rs1 (base address)
                            mux_b_select <= '0'; -- op2 = imm (offset)

                        when "1100011" => -- B-type (branch)
                            imm_raw(12)           := ir(31);
                            imm_raw(10 downto 5)  := ir(30 downto 25);
                            imm_raw(4  downto 1)  := ir(11 downto 8);
                            imm_raw(11)           := ir(7);
                            if ir(31) = '1' then
                                imm_raw(31 downto 13) := (others => '1');
                            end if;
                            mux_a_select <= '1'; -- op1 = PC (branch target = PC + offset)
                            mux_b_select <= '0'; -- op2 = imm

                        when "0110111" => -- U-type: LUI
                            imm_raw(31 downto 12) := ir(31 downto 12);
                            mux_a_select <= '0'; -- op1 doesn't matter for LUI
                            mux_b_select <= '0'; -- op2 = imm (ALU returns op2 for LUI)

                        when "0010111" => -- U-type: AUIPC
                            imm_raw(31 downto 12) := ir(31 downto 12);
                            mux_a_select <= '1'; -- op1 = PC
                            mux_b_select <= '0'; -- op2 = imm

                        when "1101111" => -- J-type: JAL
                            imm_raw(20)           := ir(31);
                            imm_raw(10 downto 1)  := ir(30 downto 21);
                            imm_raw(11)           := ir(20);
                            imm_raw(19 downto 12) := ir(19 downto 12);
                            if ir(31) = '1' then
                                imm_raw(31 downto 21) := (others => '1');
                            end if;
                            mux_a_select <= '1'; -- op1 = PC (target = PC + offset)
                            mux_b_select <= '0'; -- op2 = imm

                        when others =>
                            -- do nothing, should hopefully never get to this case
                            null;
                    end case;

                    imm <= imm_raw;
                    state <= EXECUTE;

                -- EXECUTE: ALU result is combinatorial.
                --          Decide branch taken / not taken → mux_pc_select.
                --          For JAL/JALR also redirect PC via alu_out.
                when EXECUTE =>
                    opcode := ir(6 downto 0);
                    funct3 := "0" & ir(14 downto 12);

                    case opcode is
                        when "1100011" => -- B-type branches
                            case funct3 is
                                when x"0" => -- BEQ: take if A = B
                                    if A = B then
                                        mux_pc_select <= '0';
                                    else
                                        mux_pc_select <= '1';
                                    end if;
                                when x"1" => -- BNE: take if A /= B
                                    if A /= B then
                                        mux_pc_select <= '0';
                                    else
                                        mux_pc_select <= '1';
                                    end if;
                                when x"4" => -- BLT (signed)
                                    if signed(A) < signed(B) then
                                        mux_pc_select <= '0';
                                    else
                                        mux_pc_select <= '1';
                                    end if;
                                when x"5" => -- BGE (signed)
                                    if signed(A) >= signed(B) then
                                        mux_pc_select <= '0';
                                    else
                                        mux_pc_select <= '1';
                                    end if;
                                when x"6" => -- BLTU (unsigned)
                                    if unsigned(A) < unsigned(B) then
                                        mux_pc_select <= '0';
                                    else
                                        mux_pc_select <= '1';
                                    end if;
                                when x"7" => -- BGEU (unsigned)
                                    if unsigned(A) >= unsigned(B) then
                                        mux_pc_select <= '0';
                                    else
                                        mux_pc_select <= '1';
                                    end if;
                                when others =>
                                    mux_pc_select <= '1';
                            end case;

                        when "1101111" | "1100111" => -- JAL / JALR: always jump
                            mux_pc_select <= '0'; -- use alu_out as next PC

                        when others =>
                            mux_pc_select <= '1'; -- sequential
                    end case;

                    state <= MEM;

                -- MEM: Initiate memory read (for LW) or write (for SW).
                --      Set reg_write and mux_write_select for WRITEBACK.
                --      The memory samples address this cycle; readdata
                --      (lmd) is valid at the WRITEBACK rising edge.
                when MEM =>
                    opcode := ir(6 downto 0);

                    if opcode = "0000011" then -- lw
                        mem_read <= '1';
                        mux_write_select <= 1; -- write-back value loaded from memory
                        reg_write  <= '1';
                    elsif opcode = "0100011" then -- SW
                        mem_write  <= '1';
                        reg_write  <= '0';
                    elsif opcode = "1100011" then -- branch: no writeback
                        reg_write  <= '0';
                    elsif opcode = "1101111" or opcode = "1100111" then -- jal or jalr
                        mux_write_select <= 2;   -- write back return address (npc)
                        reg_write       <= '1';
                    else -- R-type, I-type ALU, LUI, AUIPC
                        mux_write_select <= 0;   -- write-back output of alu
                        reg_write       <= '1';
                    end if;

                    state <= WRITEBACK;

                -- WRITEBACK: RF write_process sees reg_write='1' (set in
                --            MEM) and writes on this rising edge.
                --            Update PC; deassert memory controls.
                when WRITEBACK =>
                    mem_read  <= '0';
                    mem_write <= '0';
                    reg_write <= '0';
                    pc <= to_integer(unsigned(mux_pc));
                    state <= FETCH;

            end case;
        end if;
    end process;
end arch;
