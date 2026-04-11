library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rf is
    port (
        clk : in std_logic;
        reset : in std_logic;
        read_addr1 : in std_logic_vector(4 downto 0);
        read_addr2 : in std_logic_vector(4 downto 0);
        write_addr : in std_logic_vector(4 downto 0);
        write_data : in std_logic_vector(31 downto 0);
        read_data1 : out std_logic_vector(31 downto 0);
        read_data2 : out std_logic_vector(31 downto 0)
    );
end rf;

architecture arch of rf is 
    type reg_file is array(31 downto 0) of std_logic_vector(31 downto 0);

    signal my_rf : reg_file;
begin
    reset_process: process(reset)
    begin
        if reset = '1' then
            for i in 0 to 31 loop
                my_rf(i) <= (others => '0');
            end loop;
        end if;
    end process;

    read_process: process(read_addr1, read_addr2)
        variable index1 : integer;
        variable index2 : integer;
    begin
        index1 := to_integer(unsigned(read_addr1));
        index2 := to_integer(unsigned(read_addr2));

        read_data1 <= my_rf(index1);
        read_data2 <= my_rf(index2);
    end process;

    write_process: process(clk)
        variable write_index : integer;
    begin
        if rising_edge(clk) then
            write_index := to_integer(unsigned(write_addr));
            my_rf(write_index) <= write_data;
        end if;
    end process;

end arch;