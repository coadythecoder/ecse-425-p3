library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alu is
    port(
        instruction : in std_logic_vector(31 downto 0);
        A : in std_logic_vector(31 downto 0);
        B : in std_logic_vector(31 downto 0);
        result : out std_logic_vector(31 downto 0)
    );
end alu;

architecture arch of alu is 
begin
    -- stuff
    process (instruction)
        variable opcode : std_logic_vector(6 downto 0);
        variable funct3 : std_logic_vector(2 downto 0);
        variable funct7 : std_logic_vector(6 downto 0);
        variable rs1 : signed(31 downto 0);
        variable rs2 : signed(31 downto 0);
    begin
        rs1 := signed(A);
        rs2 := signed(B);
        opcode := instruction(6 downto 0);
        funct3 := instruction(14 downto 12);
        funct7 := instruction(31 downto 25);
        case opcode is 
            when '0110011' =>
                case funct3 is
                    when x"0" =>
                        if funct7 = x"00" then -- add
                            result <= std_logic_vector(rs1 + rs2);
                        elsif funct7 = x"01" then -- mul
                            -- mul
                        elsif funct7 = x"20" then -- sub
                            result <= std_logic_vector(rs1 - rs2);
                        end if;
                    when x"6" => -- or
                        result <= A or B;
                    when x"7" => -- and
                        result <= A and B;
                    when x"1" => -- sll
                        result <= rs1 << rs2
                    when x"5" =>
                        -- shift right logical or shift right arithmetic
                end case;
            when '0010011' =>
                case funct3 is
                    when x"0" =>
                        -- add immediate
                    when x"4" =>
                        -- xor immediate
                    when x"6" => 
                        -- or immediate
                    when x"7" =>
                        -- and immediate
                    when x"2" =>
                        -- set less than immediate
                end case;
        end case;
    end process;
end arch;

