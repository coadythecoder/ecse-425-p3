library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity intermediate_reg is
    port (
        clk        : in  std_logic;
        reset      : in  std_logic;
        enable     : in  std_logic;
        instr_in   : in  std_logic_vector(31 downto 0);
        pc_in      : in  std_logic_vector(31 downto 0);
        instr_out  : out std_logic_vector(31 downto 0);
        pc_out     : out std_logic_vector(31 downto 0)
    );
end intermediate_reg;

architecture behavioral of intermediate_reg is
    signal instr_reg : std_logic_vector(31 downto 0);
    signal pc_reg    : std_logic_vector(31 downto 0);
begin

    process(clk, reset)
    begin
        if reset = '1' then
            instr_reg <= (others => '0');
            pc_reg    <= (others => '0');

        elsif rising_edge(clk) then
            if enable = '1' then
                instr_reg <= instr_in;
                pc_reg    <= pc_in;
            end if;
        end if;
    end process;

    instr_out <= instr_reg;
    pc_out    <= pc_reg;

end behavioral;