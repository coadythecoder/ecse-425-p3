library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cache_tb is
end cache_tb;

architecture behavior of cache_tb is

component cache is
generic(
    ram_size : INTEGER := 32768
);
port(
    clock : in std_logic;
    reset : in std_logic;

    -- Avalon interface --
    s_addr : in std_logic_vector (31 downto 0);
    s_read : in std_logic;
    s_readdata : out std_logic_vector (31 downto 0);
    s_write : in std_logic;
    s_writedata : in std_logic_vector (31 downto 0);
    s_waitrequest : out std_logic; 

    m_addr : out integer range 0 to ram_size-1;
    m_read : out std_logic;
    m_readdata : in std_logic_vector (7 downto 0);
    m_write : out std_logic;
    m_writedata : out std_logic_vector (7 downto 0);
    m_waitrequest : in std_logic
);
end component;

component memory is 
GENERIC(
    ram_size : INTEGER := 32768;
    mem_delay : time := 10 ns;
    clock_period : time := 1 ns
);
PORT (
    clock: IN STD_LOGIC;
    writedata: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
    address: IN INTEGER RANGE 0 TO ram_size-1;
    memwrite: IN STD_LOGIC;
    memread: IN STD_LOGIC;
    readdata: OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
    waitrequest: OUT STD_LOGIC
);
end component;
	
-- test signals 
signal reset : std_logic := '0';
signal clk : std_logic := '0';
constant clk_period : time := 1 ns;

signal s_addr : std_logic_vector (31 downto 0);
signal s_read : std_logic;
signal s_readdata : std_logic_vector (31 downto 0);
signal s_write : std_logic;
signal s_writedata : std_logic_vector (31 downto 0);
signal s_waitrequest : std_logic;

signal m_addr : integer range 0 to 2147483647;
signal m_read : std_logic;
signal m_readdata : std_logic_vector (7 downto 0);
signal m_write : std_logic;
signal m_writedata : std_logic_vector (7 downto 0);
signal m_waitrequest : std_logic;
signal test_num : integer;

begin

-- Connect the components which we instantiated above to their
-- respective signals.
dut: cache 
port map(
    clock => clk,
    reset => reset,

    s_addr => s_addr,
    s_read => s_read,
    s_readdata => s_readdata,
    s_write => s_write,
    s_writedata => s_writedata,
    s_waitrequest => s_waitrequest,

    m_addr => m_addr,
    m_read => m_read,
    m_readdata => m_readdata,
    m_write => m_write,
    m_writedata => m_writedata,
    m_waitrequest => m_waitrequest
);

MEM : memory
port map (
    clock => clk,
    writedata => m_writedata,
    address => m_addr,
    memwrite => m_write,
    memread => m_read,
    readdata => m_readdata,
    waitrequest => m_waitrequest
);
				

clk_process : process
begin
  clk <= '0';
  wait for clk_period/2;
  clk <= '1';
  wait for clk_period/2;
end process;

test_process : process
begin
    report "Initializing cache";
    test_num <= 0;
    s_read  <= '0';
    s_write <= '0';
    s_addr  <= (others => '0');
    s_writedata <= (others => '0');
    reset <= '1';
    wait for clk_period;
    reset <= '0';
    wait for clk_period;
    assert (s_waitrequest = '1' and m_waitrequest = '1') report "Error with initialization, at least one waitrequest != 1" severity error;
    report "Initialization successful";

    report "Test #1: Read + Invalid"; -- all blocks should be invalid initially
    test_num <= 1;
    wait until rising_edge(clk);  
    s_read <= '1';
    s_addr <= std_logic_vector(to_unsigned(0, 32)); 
    wait until falling_edge(s_waitrequest) for 200 ns;
    assert s_waitrequest = '0' report "TIMEOUT: read never completed" severity error;
    report "Read data (unsigned): " & integer'image(to_integer(unsigned(s_readdata)));
    wait until rising_edge(clk);
    s_read <= '0';
    wait for clk_period;


    report "Test #2: Read + Valid + Not Dirty + Equal Tag ";
    test_num <= 2;
    wait until rising_edge(clk);
    s_read <= '1';
    s_addr <= std_logic_vector(to_unsigned(0, 32));
    wait until falling_edge(s_waitrequest) for 200 ns;
    assert s_waitrequest = '0' report "TIMEOUT: read never completed" severity error;
    report "Read data (unsigned): " & integer'image(to_integer(unsigned(s_readdata)));
    wait until rising_edge(clk);
    s_read <= '0';
    wait for clk_period;


    report "Test #3: Read + Valid + Not Dirty + Not Equal Tag"; -- tag starts at bit 9 so add 2^9 to address
    test_num <= 3;
    wait until rising_edge(clk);
    s_read <= '1';
    s_addr <= std_logic_vector(to_unsigned(0 + 512, 32));
    wait until falling_edge(s_waitrequest) for 200 ns;
    assert s_waitrequest = '0' report "TIMEOUT: read never completed" severity error;
    report "Read data (unsigned): " & integer'image(to_integer(unsigned(s_readdata))); -- will keep the same value since new address is a multiple of 256 (see memory.vhd initialization)
    wait until rising_edge(clk);
    s_read <= '0';
    wait for clk_period;


    report "Test #4: Write + Invalid";
    test_num <= 4;
    wait until rising_edge(clk);
    s_write <= '1';
    s_addr <= std_logic_vector(to_unsigned(4, 32));
    s_writedata <= x"DEADBEEF";
    wait until falling_edge(s_waitrequest) for 200 ns;
    assert s_waitrequest = '0' report "TIMEOUT: read never completed" severity error;
    wait until rising_edge(clk);
    s_write <= '0';
    wait for clk_period;


    report "Test #5: Write Valid + Not Dirty + Equal Tag";
    test_num <= 5;
    wait until rising_edge(clk);
    s_write <= '1';
    s_addr <= std_logic_vector(to_unsigned(4, 32));
    s_writedata <= x"BEEFDEAD";
    wait until falling_edge(s_waitrequest) for 200 ns;
    assert s_waitrequest = '0' report "TIMEOUT: read never completed" severity error;
    wait until rising_edge(clk);
    s_write <= '0';
    wait for clk_period;


    report "Test #6: Write + Valid + Not Dirty + Not Equal Tag";
    test_num <= 6;
    s_write <= '1';
    s_addr <= std_logic_vector(to_unsigned(0, 32));
    s_writedata <= x"8BADF00D";
    wait until falling_edge(s_waitrequest) for 200 ns;
    assert s_waitrequest = '0' report "TIMEOUT: read never completed" severity error;
    wait until rising_edge(clk);
    s_write <= '0';
    wait for clk_period;


    report "Test #7: Write + Valid + Dirty + Equal Tag";
    test_num <= 7;
    s_write <= '1';
    s_addr <= std_logic_vector(to_unsigned(4, 32));
    s_writedata <= x"C0FFEEEE";
    wait until falling_edge(s_waitrequest) for 200 ns;
    assert s_waitrequest = '0' report "TIMEOUT: read never completed" severity error;
    wait until rising_edge(clk);
    s_write <= '0';
    wait for clk_period;


    report "Test #8: Read + Valid + Dirty + Equal Tag";
    test_num <= 8;
    s_read <= '1';
    s_addr <= std_logic_vector(to_unsigned(4, 32));
    wait until falling_edge(s_waitrequest) for 200 ns;
    assert s_waitrequest = '0' report "TIMEOUT: read never completed" severity error;
    report "Read data (unsigned): " & integer'image(to_integer(unsigned(s_readdata))); -- will keep the same value since new address is a multiple of 256 (see memory.vhd initialization)
    wait until rising_edge(clk);
    s_read <= '0';
    wait for clk_period;


    report "Test #9: Read + Valid + Dirty + Not Equal Tag";
    test_num <= 9;
    s_read <= '1';
    s_addr <= std_logic_vector(to_unsigned(4 + 512, 32));
    wait until falling_edge(s_waitrequest) for 200 ns;
    assert s_waitrequest = '0' report "TIMEOUT: read never completed" severity error;
    report "Read data (unsigned): " & integer'image(to_integer(unsigned(s_readdata))); -- will keep the same value since new address is a multiple of 256 (see memory.vhd initialization)
    wait until rising_edge(clk);
    s_read <= '0';
    wait for clk_period;


    report "Test 10 set-up (creating dirty block)";
    test_num <= 10;
    s_write <= '1';
    s_addr <= std_logic_vector(to_unsigned(4 + 512, 32));
    s_writedata <= x"ABADBABE";
    wait until falling_edge(s_waitrequest) for 200 ns;
    assert s_waitrequest = '0' report "TIMEOUT: read never completed" severity error;
    wait until rising_edge(clk);
    s_write <= '0';
    wait for clk_period;

    report "Test #10: Write + Valid + Dirty + Equal Tag";
    test_num <= 11;
    s_write <= '1';
    s_addr <= std_logic_vector(to_unsigned(4 + 512, 32));
    s_writedata <= x"FEEDFACE";
    wait until falling_edge(s_waitrequest) for 200 ns;
    assert s_waitrequest = '0' report "TIMEOUT: read never completed" severity error;
    wait until rising_edge(clk);
    s_write <= '0';
    wait for clk_period;



    wait until rising_edge(clk);
    s_write <= '0';
    wait for clk_period;

    report "Testbench complete";
    std.env.stop;
    wait;

end process;
	
end;