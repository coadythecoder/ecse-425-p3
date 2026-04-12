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
            clock_period : time := 1 ns
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
            clock : in std_logic;
            reset : in std_logic;
            read_addr1 : in std_logic_vector(4 downto 0);
            read_addr2 : in std_logic_vector(4 downto 0);
            write_addr : in std_logic_vector(4 downto 0);
            write_data : in std_logic_vector(31 downto 0);
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

    signal pc : integer; -- program counter
    signal npc : integer; -- new program counter value (pc + 4)
    signal ir : std_logic_vector(31 downto 0); -- instruction register, used to hold Mem[PC]
    signal A : std_logic_vector(31 downto 0); -- register to store read data 1
    signal B : std_logic_vector(31 downto 0); -- register to store reaad data 2
    signal imm : std_logic_vector(31 downto 0); -- extended (be careful) immediate value
    signal cond : std_logic; -- signal to decide whether or not to branch
    signal lmd : std_logic_vector(31 downto 0); -- register to store data loaded from memory
    signal alu_out : std_logic_vector(31 downto 0); -- register to store output of alu
    
    signal mux_a : std_logic_vector(31 downto 0); -- mux for input 1 of alu
    signal mux_b : std_logic_vector(31 downto 0); -- mux for input 2 of alu
    signal mux_pc : std_logic_vector(31 downto 0); -- mux for updating pc value
    signal mux_write : std_logic_vector(31 downto 0); -- mux for writeback
    
    signal mem_read : std_logic; -- selector to read from data memory
    signal mem_write : std_logic; -- selector to write to data memory
    signal reg_write : std_logic; -- selector to write to registers
    
    signal mux_a_select : std_logic; -- selector for mux_a
    signal mux_b_select : std_logic;  -- selector for mux_b
    signal mux_pc_select : std_logic; -- selector for mux_pc
    signal mux_write_select : integer range 0 to 2; -- selector for mux_write

    type state_type is (FETCH, DECODE, EXECUTE, MEMORY, WRITEBACK);
    signal state : state_type;

begin
    data_mem : memory port map(
        clock => clock,
        writedata => B,
        address => alu_out,
        memwrite => mem_write,
        memread => mem_read,
        readdata => lmd,
        waitrequest => open
    );

    instr_mem : memory port map(
        clock => clock,
        writedata => (others => '0'),
        address => pc,
        memwrite => open,
        memread => open,
        readdata => ir,
        waitrequest => open
    );

    reg_file : rf port map(
        clock => clock,
        reset => reset,
        read_addr1 => ir(19 downto 15),
        read_addr2 => ir(24 downto 20),
        write_addr => ir(11 downto 7),
        write_data => mux_write,
        write_enable => reg_write,
        read_data1 => A,
        read_data2 => B
    );

    my_alu : alu port map(
        instruction => ir;
        op1 => mux_a;
        op2 => mux_b;
        result => alu_out;
    );

    mux_a <= A when mux_a_select = '0' else npc;
    mux_b <= B when mux_b_select = '1' else imm;
    mux_pc <= alu_out when mux_pc_select = '0' else std_logic_vector(to_unsigned(npc, 32));
    mux_write <= alu_out when mux_write_select = 0 else lmd when mux_write_select = 1 else std_logic_vector(to_unsigned(npc, 32));

    cpu_process: process(clock, reset)
        variable opcode : std_logic_vector(6 downto 0);
        variable imm_raw : std_logic_vector(31 downto 0);
    begin
        if reset = '1' then
            pc <= 0;
            state <= FETCH;
        
        elsif rising_edge(clock) then
            case state is
                when FETCH =>
                    ir <= instr_mem(pc);
                    npc <= pc + 4;
                    state <= DECODE;
                when DECODE =>
                    opcode := ir(6 downto 0);
                    imm_raw := (others => '0');
                    
                    case opcode is
                        when "0110011" => -- R-type
                            -- no immediate value to deal with in R-type
                        
                            mux_a_select <= '0';
                            mux_b_select <= '0';
                        when "0010011" | "0000011" | "1100111"=> -- I-type
                            imm_raw(11 downto 0) := ir(31 downto 20);
                            
                            mux_a_select <= '0'; -- op1 := A
                            mux_b_select <= '1'; -- op2 := B
                        when "0100011" => -- S-type
                            imm_raw(11 downto 5) := ir(31 downto 25);
                            imm_raw(4 downto 0) := ir(11 downto 7);

                            mux_a_select <= '0'; -- op1 := A
                            mux_b_select <= '0'; -- op2 := imm
                        when "1100011" => -- B-type
                            imm_raw(12) := ir(31);
                            imm_raw(10 downto 5) := ir(30 downto 25);
                            imm_raw(4 downto 1) := ir(11 downto 8);
                            imm_raw(11) := ir(7);

                            mux_a_select <= '1'; -- op1 := PC
                            mux_b_select <= '0'; -- op2 := imm
                        when "0110111" | "0010111" => -- U-type
                            imm_raw(31 downto 12) := ir(31 downto 12);

                            mux_a_select <= '0';
                            mux_b_select <= '0';
                        when "1101111" => -- J-type
                            imm_raw(20) := ir(31);
                            imm_raw(10 downto 1) := ir(30 downto 21);
                            imm_raw(11) := ir(20);
                            imm_raw(19 downto 12) := ir(19 downto 12);

                            mux_a_select <= '0';
                            mux_b_select <= '0';
                    end case;

                    imm <= imm_raw;

                    state <= EXECUTE;
                when EXECUTE =>
                    
                    state <= MEMORY;
                when MEMORY =>

                    state <= WRITEBACK;
                when WRITEBACK =>

                    state <= FETCH;
            end case;
        
        elsif falling_edge(clock) then
        
        
        end if;
    end process;
end arch;
