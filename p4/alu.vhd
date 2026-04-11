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
    process (instruction, A, B)
        variable opcode : std_logic_vector(6 downto 0);
        variable funct3 : std_logic_vector(2 downto 0);
        variable funct7 : std_logic_vector(6 downto 0);
        variable rs1 : signed(31 downto 0);
        variable rs2 : signed(31 downto 0);
        variable temp : signed(63 downto 0);
        variable shift_amount : natural range 0 to 31;
    begin
        rs1 := signed(A);
        rs2 := signed(B);
        opcode := instruction(6 downto 0);
        funct3 := instruction(14 downto 12);
        funct7 := instruction(31 downto 25);
        shift_amount := to_integer(unsigned(B(4 downto 0)));

        result <= (others => '0');

        case opcode is 
            when "0110011" =>
                case funct3 is
                    when "000" =>
                        if funct7 = "0000000" then -- add
                            result <= std_logic_vector(rs1 + rs2);
                        elsif funct7 = "0000001" then -- mul
                            temp := rs1 * rs2;
                            result <= std_logic_vector(temp(31 downto 0));
                        elsif funct7 = "0100000" then -- sub
                            result <= std_logic_vector(rs1 - rs2);
                        end if;
                    when "110" => -- or
                        result <= A or B;
                    when "111" => -- and
                        result <= A and B;
                    when "001" => -- sll
                        result <= std_logic_vector(shift_left(unsigned(A), shift_amount));
                    when "101" =>
                        if funct7 = "0000000" then -- shift right logical
                            result <= std_logic_vector(shift_right(unsigned(A), shift_amount));
                        elsif funct7 = "0100000" then -- shift right arithmetic
                            result <= std_logic_vector(shift_right(rs1, shift_amount));
                        end if;
                    when others =>
                        null;
                end case;
            when "0010011" =>
                case funct3 is
                    when "000" => -- add imm
                        result <= std_logic_vector(rs1 + rs2);
                    when "100" => -- xor imm
                        result <= A xor B;
                    when "110" => -- or imm
                        result <= A or B;
                    when "111" => -- and imm
                        result <= A and B;
                    when "010" => -- set less than immediate (rd = (rs1<imm)?1:0)
                        if rs1 < rs2 then
                            result <= (31 downto 1 => '0') & '1';
                        end if;
                    when others =>
                        null;
                end case;
            when others =>
                null;
        end case;
    end process;
end arch;

