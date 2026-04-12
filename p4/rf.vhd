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
        write_enable : in std_logic;
        read_data1 : out std_logic_vector(31 downto 0);
        read_data2 : out std_logic_vector(31 downto 0)
    );
end rf;

architecture arch of rf is 
    type reg_file is array(31 downto 0) of std_logic_vector(31 downto 0);

    signal my_rf : reg_file;
begin
    read_process: process(read_addr1, read_addr2, my_rf)
        variable index1 : integer;
        variable index2 : integer;
    begin
        index1 := to_integer(unsigned(read_addr1));
        index2 := to_integer(unsigned(read_addr2));

        if index1 = 0 then
            read_data1 <= (others => '0');
        else
            read_data1 <= my_rf(index1);
        end if;

        if index2 = 0 then
            read_data2 <= (others => '0');
        else
            read_data2 <= my_rf(index2);
        end if;
    end process;

    write_process: process(clk, reset)
        variable write_index : integer;
    begin
        if reset = '1' then
            for i in 0 to 31 loop
                my_rf(i) <= (others => '0');
            end loop;
        elsif rising_edge(clk) then
            if write_enable = '1' then
                write_index := to_integer(unsigned(write_addr));
                if write_index /= 0 then
                    my_rf(write_index) <= write_data;
                end if;
            end if;
            my_rf(0) <= (others => '0');
        end if;
    end process;

end arch;