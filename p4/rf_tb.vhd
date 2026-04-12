library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rf_tb is
end rf_tb;

architecture behavior of rf_tb is
    component rf is
        port (
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

    type reg_model is array (0 to 31) of std_logic_vector(31 downto 0);

    signal clk : std_logic := '0';
    signal reset : std_logic := '0';
    signal read_addr1 : std_logic_vector(4 downto 0) := (others => '0');
    signal read_addr2 : std_logic_vector(4 downto 0) := (others => '0');
    signal write_addr : std_logic_vector(4 downto 0) := (others => '0');
    signal write_data : std_logic_vector(31 downto 0) := (others => '0');
    signal write_enable : std_logic := '1';
    signal read_data1 : std_logic_vector(31 downto 0);
    signal read_data2 : std_logic_vector(31 downto 0);

    constant clk_period : time := 10 ns;
    constant zero_word : std_logic_vector(31 downto 0) := (others => '0');

    function to_addr(i : integer) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(i, 5));
    end function;

begin
    dut: rf port map(
        clk => clk,
        reset => reset,
        read_addr1 => read_addr1,
        read_addr2 => read_addr2,
        write_addr => write_addr,
        write_data => write_data,
        write_enable => write_enable,
        read_data1 => read_data1,
        read_data2 => read_data2
    );

    clk_process: process
    begin
        clk <= '0';
        wait for clk_period / 2;
        clk <= '1';
        wait for clk_period / 2;
    end process;

    test_process: process
        variable model : reg_model := (others => (others => '0'));
    begin
        report "RF tests start";

        -- Reset behavior: all registers clear to zero.
        reset <= '1';
        write_addr <= (others => '0');
        write_data <= (others => '0');
        wait for 1 ns;

        for i in 0 to 31 loop
            read_addr1 <= to_addr(i);
            read_addr2 <= to_addr(i);
            wait for 1 ns;
            assert read_data1 = zero_word
                report "Reset check failed on read_data1 at register " & integer'image(i)
                severity error;
            assert read_data2 = zero_word
                report "Reset check failed on read_data2 at register " & integer'image(i)
                severity error;
        end loop;

        wait until falling_edge(clk);
        reset <= '0';
        wait for 1 ns;

        -- x0 invariance: writes to register 0 must be ignored.
        write_addr <= to_addr(0);
        write_data <= x"FFFFFFFF";
        wait until rising_edge(clk);
        wait for 1 ns;
        read_addr1 <= to_addr(0);
        read_addr2 <= to_addr(0);
        wait for 1 ns;
        assert read_data1 = zero_word and read_data2 = zero_word
            report "x0 invariance failed"
            severity error;

        -- Basic write/read correctness at low and high addresses.
        write_addr <= to_addr(1);
        write_data <= x"11111111";
        wait until rising_edge(clk);
        model(1) := x"11111111";
        model(0) := (others => '0');

        write_addr <= to_addr(31);
        write_data <= x"AAAA5555";
        wait until rising_edge(clk);
        model(31) := x"AAAA5555";
        model(0) := (others => '0');

        write_addr <= to_addr(15);
        write_data <= x"DEADBEEF";
        wait until rising_edge(clk);
        model(15) := x"DEADBEEF";
        model(0) := (others => '0');

        read_addr1 <= to_addr(1);
        read_addr2 <= to_addr(31);
        wait for 1 ns;
        assert read_data1 = model(1)
            report "Basic read failed for register 1"
            severity error;
        assert read_data2 = model(31)
            report "Basic read failed for register 31"
            severity error;

        -- Dual-read behavior with same address.
        read_addr1 <= to_addr(15);
        read_addr2 <= to_addr(15);
        wait for 1 ns;
        assert read_data1 = model(15) and read_data2 = model(15)
            report "Dual-read same-address failed"
            severity error;

        -- Read-after-write timing around rising edge.
        write_addr <= to_addr(7);
        write_data <= x"12345678";
        read_addr1 <= to_addr(7);
        read_addr2 <= to_addr(7);
        wait for 1 ns;
        assert read_data1 = model(7)
            report "RAW pre-edge value mismatch"
            severity error;

        wait until rising_edge(clk);
        model(7) := x"12345678";
        model(0) := (others => '0');
        wait for 1 ns;
        assert read_data1 = model(7)
            report "RAW post-edge value mismatch"
            severity error;

        -- Read process must react to register updates without address changes.
        write_addr <= to_addr(7);
        write_data <= x"87654321";
        wait until rising_edge(clk);
        model(7) := x"87654321";
        model(0) := (others => '0');
        wait for 1 ns;
        assert read_data1 = model(7)
            report "Read sensitivity to register-array changes failed"
            severity error;

        -- Reset-write interaction while reset is asserted.
        write_addr <= to_addr(9);
        write_data <= x"99999999";
        reset <= '1';
        model := (others => (others => '0'));
        wait until rising_edge(clk);
        wait for 1 ns;

        for i in 0 to 31 loop
            read_addr1 <= to_addr(i);
            wait for 1 ns;
            assert read_data1 = zero_word
                report "Reset/write interaction failed at register " & integer'image(i)
                severity error;
        end loop;

        wait until falling_edge(clk);
        reset <= '0';

        -- Recreate non-zero state for idle checks.
        write_addr <= to_addr(2);
        write_data <= x"02020202";
        wait until rising_edge(clk);
        model(2) := x"02020202";
        model(0) := (others => '0');

        write_addr <= to_addr(30);
        write_data <= x"30303030";
        wait until rising_edge(clk);
        model(30) := x"30303030";
        model(0) := (others => '0');

        -- Idle cycles should not corrupt state (use x0 writes as no-op cycles).
        write_addr <= to_addr(0);
        for i in 0 to 4 loop
            write_data <= std_logic_vector(to_unsigned(i + 1, 32));
            wait until rising_edge(clk);
            model(0) := (others => '0');
        end loop;

        read_addr1 <= to_addr(2);
        read_addr2 <= to_addr(30);
        wait for 1 ns;
        assert read_data1 = model(2)
            report "Idle-cycle corruption detected at register 2"
            severity error;
        assert read_data2 = model(30)
            report "Idle-cycle corruption detected at register 30"
            severity error;

        read_addr1 <= to_addr(0);
        wait for 1 ns;
        assert read_data1 = zero_word
            report "x0 lost invariance after idle cycles"
            severity error;

        report "RF tests complete";
        std.env.stop;
        wait;
    end process;
end behavior;
