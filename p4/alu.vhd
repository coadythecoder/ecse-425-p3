library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alu is
    port(
        instruction : in std_logic_vector(31 downto 0);
        op1 : in std_logic_vector(31 downto 0);
        op2 : in std_logic_vector(31 downto 0);
        result : out std_logic_vector(31 downto 0)
    );
end alu;

architecture arch of alu is 
begin
    -- stuff
    process (instruction, op1, op2)
        variable opcode : std_logic_vector(6 downto 0);
        variable funct3 : std_logic_vector(3 downto 0);
        variable funct7 : std_logic_vector(7 downto 0);
        variable rs1 : signed(31 downto 0);
        variable rs2 : signed(31 downto 0);
        variable temp : signed(63 downto 0);
        variable target : signed(31 downto 0);
        variable shift_amount : integer;
        variable op2_unsigned : unsigned(31 downto 0);
    begin
        rs1 := signed(op1);
        rs2 := signed(op2);
        opcode := instruction(6 downto 0);
        funct3 := "0" & instruction(14 downto 12);
        funct7 := "0" & instruction(31 downto 25);
        op2_unsigned := unsigned(op2);
        shift_amount := to_integer(op2_unsigned(4 downto 0));
        result <= (others => '1');
        case opcode is 
            when "0110011" =>
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
                        result <= op1 or op2;
                    when x"7" => -- and
                        result <= op1 and op2;
                    when x"1" => -- sll
                        result <= std_logic_vector(shift_left(rs1, shift_amount));
                    when x"5" =>
                        if funct7 = x"00" then -- shift right logical
                            result <= std_logic_vector(shift_right(unsigned(op1), shift_amount));
                        elsif funct7 = x"20" then -- shift right arithmetic
                            result <= std_logic_vector(shift_right(rs1, shift_amount));
                        end if;
                    when others =>
                        result <= (others => '1'); -- all 1's to be very obvious when this case happens
                end case;
            when "0010011" =>
                case funct3 is
                    when x"0" => -- add imm
                        result <= std_logic_vector(rs1 + rs2);
                    when x"4" => -- xor imm
                        result <= op1 xor op2;
                    when x"6" => -- or imm
                        result <= op1 or op2;
                    when x"7" => -- and imm
                        result <= op1 and op2;
                    when x"2" => -- set less than immediate (rd = (rs1<imm)?1:0)
                        if rs1 < rs2 then
                            result <= std_logic_vector(to_unsigned(1, 32));
                        else
                            result <= std_logic_vector(to_unsigned(0, 32));
                        end if;
                    when others =>
                        result <= (others => '1'); -- all 1's to be very obvious when this case happens
                end case;
            when "0000011" => -- load word
                result <= std_logic_vector(rs1 + rs2); -- rs1 + imm for addressing memory
            when "0100011" => -- store word
                result <= std_logic_vector(rs1 + rs2); -- rs1 + imm for addressing memory
            when "1100011" => -- branch
                result <= std_logic_vector(rs1 + rs2); -- do i need to shift imm (rs2)??? how much???
            when "1101111" => -- jump and link
                result <= std_logic_vector(rs1 + rs2); -- rs1=PC, rs2=imm do i need to shift imm??? how much???
            when "1100111" => -- jump and link reg: target = (rs1 + imm) & ~1
                target := rs1 + rs2;
                target(0) := '0';
                result <= std_logic_vector(target);
            when "0110111" => -- load upper imm: rd = imm (already formed as {ir[31:12], 12'b0})
                result <= op2;
            when "0010111" => -- add upper imm to pc: rd = PC + imm
                result <= std_logic_vector(rs1 + rs2);
            when others =>
                result <= (others => '1');  -- all 1's to be very evident when this case happens
        end case;
    end process;
end arch;

