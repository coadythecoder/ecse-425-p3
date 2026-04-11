library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rf is 
    port (
        clk : in std_logic;
        read_addr1 : in std_logic_vector(4 downto 0);
        read_addr2 : in std_logic_vector(4 downto 0);
        write_addr : in std_logic_vector(4 downto 0);
        write_data : in std_logic_vector(31 downto 0);
        read_data1 : out std_logic_vector(31 downto 0);
        read_data2 : out std_logic_vector(31 downto 0)
    );
end rf;

architecture arch of rf is 
    type reg is std_logic_vector(31 downto 0);
    type reg_file is array(31 downto 0) of reg;
begin
    read_process: process(read_addr1, read_addr2)
    begin
    
    end process;

    write_process: process(clk)
    begin

    end process;

end arch;