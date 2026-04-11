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
        variable temp : signed(63 downto 0);
        variable shift_amount : unsigned(4 downto 0);
    begin
        rs1 := signed(A);
        rs2 := signed(B);
        opcode := instruction(6 downto 0);
        funct3 := instruction(14 downto 12);
        funct7 := instruction(31 downto 25);
        shift_amount := unsigned(B)(4 downto 0);
        case opcode is 
            when '0110011' =>
                case funct3 is
                    when x"0" =>
                        if funct7 = x"00" then -- add
                            result <= std_logic_vector(rs1 + rs2);
                        elsif funct7 = x"01" then -- mul
                            temp := rs1 * rs2;
                            result <= std_logic_vector(temp(31 downto 0));
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
                        if funct7 = x"00" then -- shift right logical
                            result <= std_logic_vector(shift_right(unsigned(A), shift_amount));
                        elsif funct7 = x"20" then -- shift right arithmetic
                            result <= std_logic_vector(shift_right(rs1, shift_amount));
                        end if;
                end case;
            when '0010011' =>
                case funct3 is
                    when x"0" => -- add imm
                        result <= std_logic_vector(rs1 + rs2);
                    when x"4" => -- xor imm
                        result <= A xor B;
                    when x"6" => -- or imm
                        result <= A or B;
                    when x"7" => -- and imm
                        result <= A and B;
                    when x"2" => -- set less than immediate (rd = (rs1<imm)?1:0)
                        if rs1 < rs2 then
                            result <= to_std_logic_vector(1, 32);
                        else
                            result <= to_std_logic_vector(0, 32);
                        end if;
                end case;
        end case;
    end process;
end arch;

