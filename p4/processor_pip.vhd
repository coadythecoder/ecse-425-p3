library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity processor_pip is
    port(
        clock  : in std_logic;
        reset  : in std_logic
    );
end processor_pip;

architecture arch of processor_pip is
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
            rd_in	: in  std_logic_vector(4 downto 0);
            ir_in   : in  std_logic_vector(31 downto 0);
            mux_a_select_in   : in  std_logic;
            mux_b_select_in   : in  std_logic;
            npc_out	: out  std_logic_vector(31 downto 0);
            a_out	: out  std_logic_vector(31 downto 0);
            b_out	: out  std_logic_vector(31 downto 0);
            immval_out	: out  std_logic_vector(31 downto 0);
            rd_out	: out  std_logic_vector(4 downto 0);
            ir_out  : out std_logic_vector(31 downto 0);
            mux_a_select_out   : out  std_logic;
            mux_b_select_out   : out  std_logic
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
            rd_in	: in  std_logic_vector(4 downto 0);
            ir_in   : in  std_logic_vector(31 downto 0);
            npc_in	: in  std_logic_vector(31 downto 0);
            mux_pc_select_out	: out  std_logic;
            aluout_out	: out  std_logic_vector(31 downto 0);
            b_out	: out  std_logic_vector(31 downto 0);
            rd_out	: out  std_logic_vector(4 downto 0);
            ir_out   : out  std_logic_vector(31 downto 0);
            npc_out	: out  std_logic_vector(31 downto 0)
        );
    end component;

    component mem_wb_reg is
        port (
            clk	: in  std_logic;
            reset	: in  std_logic;
            enable	: in  std_logic;
            regwrite_in	: in  std_logic;
            mux_write_select_in	: in  std_logic_vector(1 downto 0);
            aluout_in	: in  std_logic_vector(31 downto 0);
            mem_ldr_result_in	: in  std_logic_vector(31 downto 0);
            rd_in	: in  std_logic_vector(4 downto 0);
            npc_in	: in  std_logic_vector(31 downto 0);
            regwrite_out	: out  std_logic;
            mux_write_select_out	: out  std_logic_vector(1 downto 0);
            aluout_out	: out  std_logic_vector(31 downto 0);
            mem_ldr_result_out	: out  std_logic_vector(31 downto 0);
            rd_out	: out  std_logic_vector(4 downto 0);
            npc_out	: out  std_logic_vector(31 downto 0)
        );
    end component;

    --TODO: MANY OF THESE SIGNALS ARE LEFTOVER GLOBALSIGNALS FROM MULTISTAGE UNPIPELINED IMPLEMENTATIONS, 
    --REMOVE UNUSED SIGNALS
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

    signal if_ir_in  : std_logic_vector(31 downto 0);
    signal if_pc_in  : std_logic_vector(31 downto 0);
    signal if_id_ir  : std_logic_vector(31 downto 0);
    signal if_id_pc  : std_logic_vector(31 downto 0);


    signal id_npc_in  : std_logic_vector(31 downto 0);
    signal id_a_data  : std_logic_vector(31 downto 0);
    signal id_b_data  : std_logic_vector(31 downto 0);
    signal id_a_in    : std_logic_vector(31 downto 0);
    signal id_b_in    : std_logic_vector(31 downto 0);
    signal id_imm     : std_logic_vector(31 downto 0);
    signal id_rd      : std_logic_vector(4 downto 0);
    signal id_ir      : std_logic_vector(31 downto 0);
    signal id_mux_a_select : std_logic;
    signal id_mux_b_select : std_logic;
    signal id_ex_npc  : std_logic_vector(31 downto 0);
    signal id_ex_a    : std_logic_vector(31 downto 0);
    signal id_ex_b    : std_logic_vector(31 downto 0);
    signal id_ex_imm  : std_logic_vector(31 downto 0);
    signal id_ex_rd   : std_logic_vector(4 downto 0);
    signal id_ex_ir   : std_logic_vector(31 downto 0);
    signal id_ex_mux_a_select : std_logic;
    signal id_ex_mux_b_select : std_logic;

    signal ex_mux_pc_select : std_logic;
    signal ex_alu_out : std_logic_vector(31 downto 0);
    signal ex_b       : std_logic_vector(31 downto 0);
    signal ex_rd      : std_logic_vector(4 downto 0);
    signal ex_ir      : std_logic_vector(31 downto 0);
    signal ex_npc      : std_logic_vector(31 downto 0);
    signal ex_mem_mux_pc_select : std_logic;
    signal ex_mem_alu_out       : std_logic_vector(31 downto 0);
    signal ex_mem_alu_out_int : integer := 0; --memory takes int as address input
    signal ex_mem_b             : std_logic_vector(31 downto 0);
    signal ex_mem_rd            : std_logic_vector(4 downto 0);
    signal ex_mem_ir            : std_logic_vector(31 downto 0);
    signal ex_mem_npc            : std_logic_vector(31 downto 0);
    signal ex_stage_b_in         : std_logic_vector(31 downto 0);
    signal ex_stage_rd_in        : std_logic_vector(4 downto 0);
    signal ex_stage_ir_in        : std_logic_vector(31 downto 0);
    signal ex_stage_npc_in       : std_logic_vector(31 downto 0);

    signal mem_regwrite        : std_logic;
    signal mem_mux_write_select : std_logic_vector(1 downto 0);
    signal mem_alu_out   : std_logic_vector(31 downto 0);
    signal mem_data_out  : std_logic_vector(31 downto 0);
    signal mem_rd        : std_logic_vector(4 downto 0);
    signal mem_npc  : std_logic_vector(31 downto 0);
    signal wb_regwrite        : std_logic;
    signal wb_mux_write_select : std_logic_vector(1 downto 0);
    signal wb_alu_out         : std_logic_vector(31 downto 0);
    signal wb_mem_data        : std_logic_vector(31 downto 0);
    signal wb_rd              : std_logic_vector(4 downto 0);
    signal wb_npc  : std_logic_vector(31 downto 0);

    signal ex_mem_is_load   : std_logic;
    signal ex_mem_writes_rd : std_logic;
    signal fwd_rs1          : std_logic_vector(31 downto 0);
    signal fwd_rs2          : std_logic_vector(31 downto 0);
    signal flush_id         : std_logic;
    signal pc_base_ex       : std_logic_vector(31 downto 0);

begin
    -- Combinatorial conversions
    --alu_out_int <= to_integer(signed(alu_out));
    --data_addr   <= alu_out_int / 4 when alu_out_int >= 0 else 0; -- prevent overflow
    -- Clamp PC to valid instruction memory range [0, 32767]
    pc_word     <= pc / 4 when (pc / 4) < 32768 else 32767;

    -- Data forwarding: Forward ALU results from EX/MEM stage if the destination register matches
    ex_mem_is_load <= '1' when ex_mem_ir(6 downto 0) = "0000011" else '0';
    ex_mem_writes_rd <= '1' when ex_mem_rd /= "00000" and (
        ex_mem_ir(6 downto 0) = "0110011" or  -- R-type
        ex_mem_ir(6 downto 0) = "0010011" or  -- I-type ALU
        ex_mem_ir(6 downto 0) = "0000011" or  -- load
        ex_mem_ir(6 downto 0) = "0110111" or  -- LUI
        ex_mem_ir(6 downto 0) = "0010111" or  -- AUIPC
        ex_mem_ir(6 downto 0) = "1101111" or  -- JAL
        ex_mem_ir(6 downto 0) = "1100111"    -- JALR
    ) else '0';

    -- Forward from EX/MEM stage (for instructions not in load phase) or WB stage
    fwd_rs1 <= ex_mem_alu_out when ex_mem_writes_rd = '1' and ex_mem_is_load = '0' and ex_mem_rd = id_ex_ir(19 downto 15)
        else mux_write when wb_regwrite = '1' and wb_rd /= "00000" and wb_rd = id_ex_ir(19 downto 15)
        else id_ex_a;

    fwd_rs2 <= ex_mem_alu_out when ex_mem_writes_rd = '1' and ex_mem_is_load = '0' and ex_mem_rd = id_ex_ir(24 downto 20)
        else mux_write when wb_regwrite = '1' and wb_rd /= "00000" and wb_rd = id_ex_ir(24 downto 20)
        else id_ex_b;

    -- MEM stage controls must be combinational with EX/MEM opcode.
    mem_read <= '1' when ex_mem_ir(6 downto 0) = "0000011" else '0';
    mem_write <= '1' when ex_mem_ir(6 downto 0) = "0100011" else '0';
    mem_regwrite <= '0' when ex_mem_ir(6 downto 0) = "0100011" or ex_mem_ir(6 downto 0) = "1100011" else '1';
    mem_mux_write_select <= "01" when ex_mem_ir(6 downto 0) = "0000011"
        else "10" when ex_mem_ir(6 downto 0) = "1101111" or ex_mem_ir(6 downto 0) = "1100111"
        else "00";

    flush_id <= '1' when ex_mux_pc_select = '0' and (
        id_ex_ir(6 downto 0) = "1100011" or
        id_ex_ir(6 downto 0) = "1101111" or
        id_ex_ir(6 downto 0) = "1100111"
    ) else '0';

    ex_control_process: process(id_ex_ir, fwd_rs1, fwd_rs2)
        variable funct3_ex : std_logic_vector(2 downto 0);
    begin
        ex_mux_pc_select <= '1';

        if id_ex_ir(6 downto 0) = "1100011" then
            funct3_ex := id_ex_ir(14 downto 12);
            case funct3_ex is
                when "000" => -- BEQ
                    if fwd_rs1 = fwd_rs2 then
                        ex_mux_pc_select <= '0';
                    end if;
                when "001" => -- BNE
                    if fwd_rs1 /= fwd_rs2 then
                        ex_mux_pc_select <= '0';
                    end if;
                when "100" => -- BLT
                    if signed(fwd_rs1) < signed(fwd_rs2) then
                        ex_mux_pc_select <= '0';
                    end if;
                when "101" => -- BGE
                    if signed(fwd_rs1) >= signed(fwd_rs2) then
                        ex_mux_pc_select <= '0';
                    end if;
                when "110" => -- BLTU
                    if unsigned(fwd_rs1) < unsigned(fwd_rs2) then
                        ex_mux_pc_select <= '0';
                    end if;
                when "111" => -- BGEU
                    if unsigned(fwd_rs1) >= unsigned(fwd_rs2) then
                        ex_mux_pc_select <= '0';
                    end if;
                when others =>
                    null;
            end case;
        elsif id_ex_ir(6 downto 0) = "1101111" or id_ex_ir(6 downto 0) = "1100111" then
            ex_mux_pc_select <= '0';
        end if;
    end process;

    -- When a branch/jump redirect is asserted, squash the stale younger EX instruction.
    ex_stage_b_in   <= (others => '0') when flush_id = '1' else fwd_rs2;
    ex_stage_rd_in  <= (others => '0') when flush_id = '1' else id_ex_rd;
    ex_stage_ir_in  <= (others => '0') when flush_id = '1' else id_ex_ir;
    ex_stage_npc_in <= (others => '0') when flush_id = '1' else id_ex_npc;

    -- Muxes combinatorial
    -- For PC-relative ops, use current PC (= npc-4), not npc.
    pc_base_ex <= std_logic_vector(unsigned(id_ex_npc) - 4);
    -- mux_a: '0' => rs1 register (with forwarding), '1' => current PC (for branch/JAL targets)
    mux_a <= fwd_rs1 when id_ex_mux_a_select = '0' else pc_base_ex;
    -- mux_b: '0' => immediate, '1' => rs2 register (with forwarding)
    mux_b <= id_ex_imm when id_ex_mux_b_select = '0' else fwd_rs2;
    -- mux_pc: '0' => alu_out (branch/jump target from EX), '1' => npc (fall-through)
    -- Use direct pc+4 instead of npc to avoid stale values
    mux_pc <= ex_alu_out when ex_mux_pc_select = '0' else std_logic_vector(to_unsigned(pc + 4, 32));
    -- mux_write: 0 => alu_out, 1 => lmd (loaded value), 2 => npc (JAL return addr)
    mux_write <= wb_alu_out when wb_mux_write_select = "00"
            else wb_mem_data    when wb_mux_write_select = "01"
            else wb_npc; --for jumping

    -- Data memory (byte-addressed in RISC-V; word-indexed here via data_addr = alu_out/4)
    data_mem : memory port map(
        clock => clock,
        writedata => ex_mem_b, --data to be stored into mem is the ex/mem output b
        address => ex_mem_alu_out_int, --adress is the ex/mem aluout output
        memwrite => mem_write,
        memread => mem_read,
        readdata => mem_data_out, --output of data mem is connected to input in mem/wb
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
            readdata => ir, --instruction go straight to if/id ir input
            waitrequest => open
        );

    -- Register file
    reg_file : rf port map(
        clk => clock,
        reset => reset,
        -- Read addresses come from the instruction currently in IF/ID (if_id_ir), not the delayed id_ir
        -- This ensures we read operands for the instruction in the current ID stage
        read_addr1 => if_id_ir(19 downto 15),
        read_addr2 => if_id_ir(24 downto 20),
        write_addr => wb_rd, --rd output of mem/wb connects to reg file write address
        write_data => mux_write,
        write_enable => wb_regwrite, --this is controlled by regwrite output of mem/wb
        read_data1 => id_a_data, --outputs of reg file connects to inputs of id/ex
        read_data2 => id_b_data
    );

    -- ALU
    my_alu : alu port map(
        instruction => id_ex_ir, --alu operation determined by ir output of id/ex
        op1 => mux_a,
        op2 => mux_b,
        result => ex_alu_out --alu output connected to input of ex/mem
    );

    --------------------------------------------------------------------
    -- IF/ID REGISTER
    --------------------------------------------------------------------
    u_if_id : if_id_reg
    port map (
        clk    => clock,
        reset  => reset,
        enable => '1',

        ir_in  => if_ir_in,
        pc_in  => if_pc_in,

        ir_out => if_id_ir,
        pc_out => if_id_pc
    );

    --------------------------------------------------------------------
    -- ID/EX REGISTER
    --------------------------------------------------------------------
    u_id_ex : id_ex_reg
    port map (
        clk    => clock,
        reset  => reset,
        enable => '1',

        npc_in        => id_npc_in,
        a_in          => id_a_in,
        b_in          => id_b_in,
        immval_in     => id_imm,
        rd_in         => id_rd,
        ir_in         => id_ir,

        mux_a_select_in => id_mux_a_select,
        mux_b_select_in => id_mux_b_select,

        npc_out       => id_ex_npc,
        a_out         => id_ex_a,
        b_out         => id_ex_b,
        immval_out    => id_ex_imm,
        rd_out        => id_ex_rd,
        ir_out        => id_ex_ir,

        mux_a_select_out => id_ex_mux_a_select,
        mux_b_select_out => id_ex_mux_b_select
    );

    --------------------------------------------------------------------
    -- EX/MEM REGISTER
    --------------------------------------------------------------------
    u_ex_mem : ex_mem_reg
    port map (
        clk    => clock,
        reset  => reset,
        enable => '1',

        mux_pc_select_in => ex_mux_pc_select,
        aluout_in        => ex_alu_out,
        b_in             => ex_stage_b_in,
        rd_in            => ex_stage_rd_in,
        ir_in            => ex_stage_ir_in,
        npc_in           => ex_stage_npc_in,

        mux_pc_select_out => ex_mem_mux_pc_select,
        aluout_out        => ex_mem_alu_out,
        b_out             => ex_mem_b,
        rd_out            => ex_mem_rd,
        ir_out            => ex_mem_ir,
        npc_out            => ex_mem_npc
    );

    --------------------------------------------------------------------
    -- MEM/WB REGISTER
    --------------------------------------------------------------------
    u_mem_wb : mem_wb_reg
    port map (
        clk    => clock,
        reset  => reset,
        enable => '1',

        regwrite_in        => mem_regwrite,
        mux_write_select_in=> mem_mux_write_select,
        aluout_in          => ex_mem_alu_out,
        mem_ldr_result_in  => mem_data_out,
        rd_in              => ex_mem_rd,
        npc_in             => ex_mem_npc,

        regwrite_out        => wb_regwrite,
        mux_write_select_out=> wb_mux_write_select,
        aluout_out          => wb_alu_out,
        mem_ldr_result_out  => wb_mem_data,
        rd_out              => wb_rd,
        npc_out              => wb_npc
    );

    cpu_process: process(clock, reset)
        variable opcode_id : std_logic_vector(6 downto 0);
        variable opcode_mem : std_logic_vector(6 downto 0);
        variable imm_raw : std_logic_vector(31 downto 0);
        variable rd : std_logic_vector(6 downto 0);
        variable addr_word : integer;
    begin
        if reset = '1' then
            pc <= 0;

            -- =========================
            -- IF stage
            -- =========================
            if_ir_in  <= (others => '0');
            if_pc_in  <= (others => '0');

            -- =========================
            -- ID stage
            -- =========================
            id_npc_in <= (others => '0');
            id_a_in   <= (others => '0');
            id_b_in   <= (others => '0');
            id_imm    <= (others => '0');
            id_rd     <= (others => '0');
            id_ir     <= (others => '0');

            id_mux_a_select <= '0';
            id_mux_b_select <= '0';

            -- =========================
            -- EX stage
            -- =========================
            ex_b             <= (others => '0');
            ex_rd            <= (others => '0');
            ex_ir            <= (others => '0');
            ex_npc           <= (others => '0');
            ex_mem_alu_out_int   <= 0;

            -- =========================
            -- MEM stage
            -- =========================
            mem_alu_out          <= (others => '0');
            mem_rd               <= (others => '0');
            mem_npc              <= (others => '0');

        elsif rising_edge(clock) then
            npc <= pc + 4;
            if_pc_in <= std_logic_vector(to_unsigned(pc + 4, 32));
            pc <= to_integer(unsigned(mux_pc));

            id_npc_in <= if_id_pc; --if/id output npc and id/ex input npc connected
            ex_npc <= id_ex_npc; --id/ex npc output connected to ex/mem npc input
            mem_npc <= ex_mem_npc; --mem/wb npc input connected to ex/mem npc output
            ex_ir <= id_ex_ir; --ir passed directly from id/ex output to ex/mem input
            ex_rd <= id_ex_rd; --id/ex output rd same as ex/mem input rd
            mem_rd <= ex_mem_rd; --ex/mem output rd same as mem/wb input rd

            ex_b <= id_ex_b; --id/ex B output same as ex/mem b input
            mem_alu_out <= ex_mem_alu_out; --ex/mem aluout same as mem/wb alu value input

            -- Address bounds checking to prevent out-of-range errors
            -- Extract word address from byte address and clamp to valid range [0, 32767]
            if signed(ex_mem_alu_out) < 0 then
                ex_mem_alu_out_int <= 0;
            else
                addr_word := to_integer(unsigned(ex_mem_alu_out(31 downto 2)));
                if addr_word > 32767 then
                    ex_mem_alu_out_int <= 32767;
                else
                    ex_mem_alu_out_int <= addr_word;
                end if;
            end if;

            if_ir_in <= ir;
            if flush_id = '1' then
                if_ir_in <= (others => '0');
            end if;

            id_mux_a_select <= '0';
            id_mux_b_select <= '0';
            imm_raw := (others => '0');

            if flush_id = '1' then
                -- Squash the wrong-path instruction already sitting in IF/ID.
                id_ir   <= (others => '0');
                id_a_in <= (others => '0');
                id_b_in <= (others => '0');
                id_imm  <= (others => '0');
                id_rd   <= (others => '0');
            else
                id_ir   <= if_id_ir;
                id_a_in <= id_a_data;
                id_b_in <= id_b_data;

                opcode_id  := if_id_ir(6 downto 0);

                case opcode_id is
                    when "0110011" => -- R-type
                        id_mux_a_select <= '0'; -- op1 = rs1
                        id_mux_b_select <= '1'; -- op2 = rs2 (register B)

                    when "0010011" | "0000011" | "1100111" => -- I-type ALU / load / JALR
                        imm_raw(11 downto 0) := if_id_ir(31 downto 20);
                        -- sign-extend from bit 11
                        if if_id_ir(31) = '1' then
                            imm_raw(31 downto 12) := (others => '1');
                        end if;
                        id_mux_a_select <= '0'; -- op1 = rs1
                        id_mux_b_select <= '0'; -- op2 = imm

                    when "0100011" => -- S-type (store)
                        imm_raw(11 downto 5) := if_id_ir(31 downto 25);
                        imm_raw(4  downto 0) := if_id_ir(11 downto 7);
                        if if_id_ir(31) = '1' then
                            imm_raw(31 downto 12) := (others => '1');
                        end if;
                        id_mux_a_select <= '0'; -- op1 = rs1 (base address)
                        id_mux_b_select <= '0'; -- op2 = imm (offset)

                    when "1100011" => -- B-type (branch)
                        imm_raw(12)           := if_id_ir(31);
                        imm_raw(10 downto 5)  := if_id_ir(30 downto 25);
                        imm_raw(4  downto 1)  := if_id_ir(11 downto 8);
                        imm_raw(11)           := if_id_ir(7);
                        if if_id_ir(31) = '1' then
                            imm_raw(31 downto 13) := (others => '1');
                        end if;
                        id_mux_a_select <= '1'; -- op1 = PC (branch target = PC + offset)
                        id_mux_b_select <= '0'; -- op2 = imm

                    when "0110111" => -- U-type: LUI
                        imm_raw(31 downto 12) := if_id_ir(31 downto 12);
                        id_mux_a_select <= '0'; -- op1 doesn't matter for LUI
                        id_mux_b_select <= '0'; -- op2 = imm (ALU returns op2 for LUI)

                    when "0010111" => -- U-type: AUIPC
                        imm_raw(31 downto 12) := if_id_ir(31 downto 12);
                        id_mux_a_select <= '1'; -- op1 = PC
                        id_mux_b_select <= '0'; -- op2 = imm

                    when "1101111" => -- J-type: JAL
                        imm_raw(20)           := if_id_ir(31);
                        imm_raw(10 downto 1)  := if_id_ir(30 downto 21);
                        imm_raw(11)           := if_id_ir(20);
                        imm_raw(19 downto 12) := if_id_ir(19 downto 12);
                        if if_id_ir(31) = '1' then
                            imm_raw(31 downto 21) := (others => '1');
                        end if;
                        id_mux_a_select <= '1'; -- op1 = PC (target = PC + offset)
                        id_mux_b_select <= '0'; -- op2 = imm

                    when others =>
                        null;
                end case;

                id_imm <= imm_raw;
                id_rd <= if_id_ir(11 downto 7); --extract rd from if_id_ir
            end if;
                
            opcode_mem  := ex_mem_ir(6 downto 0);



            
        end if;
    end process;
    
end arch;
