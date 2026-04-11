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

    data_mem : memory port map(
        clock => clock;
        writedata => B;
        address => alu_out;
        memwrite => _;
        memread => _;
        readdata => lmd;
        waitrequest => _
    );

    instr_mem : memory port map(
        clock => clock;
        writedata => (others => '0');
        address => pc;
        memwrite => _;
        memread => _;
        readdata => ir;
        waitrequest => _
    );

    reg_file : rf port map(
        clock => clock;
        reset => reset;
        read_addr1 => ir(19 downto 15);
        read_addr2 => ir(24 downto 20);
        write_addr => ir(11 downto 7);
        write_data => mux_write;
        read_data1 => A;
        read_data2 => B
    );

begin
    mux_pc <= alu_out when cond = '1' else npc;
    -- mux_write <= lmd when 


    cpu_process: process(clock, reset)
    begin
        if reset = '1' then
            pc <= 0;
        
        elsif rising_edge(clock) then

        
        elsif falling_edge(clock) then
        
        
        end if;
    end process;
end arch;
