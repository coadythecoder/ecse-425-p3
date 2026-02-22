library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity memory_tb is
end memory_tb;

architecture behaviour of memory_tb IS

--Declare the component that you are testing:
    component memory is
        generic(
            ram_size : integer := 32768;
            mem_delay : time := 10 ns;
            clock_period : time := 1 ns
        );
        port (
            clock: in std_logic;
            writedata: in std_logic_vector (7 downto 0);
            address: in integer range 0 to ram_size-1;
            memwrite: in std_logic_vector := '0';
            memread: in std_logic := '0';
            readdata: out std_logic_vector (7 downto 0);
            waitrequest: out std_logic
        );
    end component;

    --all the input signals with initial values
    signal clk : std_logic := '0';
    constant clk_period : time := 1 ns;
    signal writedata: std_logic_vector(7 downto 0);
    signal address: integer range 0 to 32768-1;
    signal memwrite: std_logic := '0';
    signal memread: std_logic := '0';
    signal readdata: std_logic_vector (7 downto 0);
    signal waitrequest: std_logic;

begin

    --dut => Device Under Test
    dut: memory generic map(
            ram_size => 15
                )
                port map(
                    clk,
                    writedata,
                    address,
                    memwrite,
                    memread,
                    readdata,
                    waitrequest
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
        wait for clk_period;
        address <= 14; 
        writedata <= X"12";
        memwrite <= '1';
        
        --waits are NOT synthesizable and should not be used in a hardware design
        wait until rising_edge(waitrequest);
        memwrite <= '0';
        memread <= '1';
        wait until rising_edge(waitrequest);
        assert readdata = x"12" report "write unsuccessful" severity error;
        memread <= '0';
        wait for clk_period;
        address <= 12;memread <= '1';
        wait until rising_edge(waitrequest);
        assert readdata = x"0c" report "write unsuccessful" severity error;
        memread <= '0';
        wait;

    end process;

 
end;