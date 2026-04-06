library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alu is
    port(
        instruction: in std_logic_vector(31 downto 0);
        result: out std_logic_vector(31 downto 0)
    );
end alu;

architecture arch of alu is 
begin
    -- stuff
end arch;

