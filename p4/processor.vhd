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
begin
    cpu_process process(clock, reset)
    begin
        if reset = '1' then
        
        
        elsif rising_edge(clock) then

        
        elsif falling_edge(clock) then
        
        
        end if;
    end process;
end arch;
