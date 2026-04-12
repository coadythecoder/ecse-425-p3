library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alu_tb is
end alu_tb;

architecture behavior of alu_tb is
    component alu is
        port(
            instruction : in std_logic_vector(31 downto 0);
            op1 : in std_logic_vector(31 downto 0);
            op2 : in std_logic_vector(31 downto 0);
            result : out std_logic_vector(31 downto 0)
        );
    end component;

    signal instruction : std_logic_vector(31 downto 0) := (others => '0');
    signal A : std_logic_vector(31 downto 0) := (others => '0');
    signal B : std_logic_vector(31 downto 0) := (others => '0');
    signal result : std_logic_vector(31 downto 0);

    function make_r(
        funct7 : std_logic_vector(6 downto 0);
        funct3 : std_logic_vector(2 downto 0)
    ) return std_logic_vector is
        variable instr : std_logic_vector(31 downto 0) := (others => '0');
    begin
        instr(31 downto 25) := funct7;
        instr(24 downto 20) := "00010";
        instr(19 downto 15) := "00001";
        instr(14 downto 12) := funct3;
        instr(11 downto 7) := "00011";
        instr(6 downto 0) := "0110011";
        return instr;
    end function;

    function make_i(
        imm12 : std_logic_vector(11 downto 0);
        funct3 : std_logic_vector(2 downto 0)
    ) return std_logic_vector is
        variable instr : std_logic_vector(31 downto 0) := (others => '0');
    begin
        instr(31 downto 20) := imm12;
        instr(19 downto 15) := "00001";
        instr(14 downto 12) := funct3;
        instr(11 downto 7) := "00011";
        instr(6 downto 0) := "0010011";
        return instr;
    end function;

    function next_rand(x : std_logic_vector(31 downto 0)) return std_logic_vector is
        variable v : unsigned(31 downto 0) := unsigned(x);
    begin
        v := v xor shift_left(v, 13);
        v := v xor shift_right(v, 17);
        v := v xor shift_left(v, 5);
        return std_logic_vector(v);
    end function;

    function gt_result(
        instr : std_logic_vector(31 downto 0);
        a_in : std_logic_vector(31 downto 0);
        b_in : std_logic_vector(31 downto 0)
    ) return std_logic_vector is
        variable opcode : std_logic_vector(6 downto 0);
        variable funct3 : std_logic_vector(2 downto 0);
        variable funct7 : std_logic_vector(6 downto 0);
        variable rs1 : signed(31 downto 0);
        variable rs2 : signed(31 downto 0);
        variable temp : signed(63 downto 0);
        variable shift_amount : natural range 0 to 31;
        variable exp : std_logic_vector(31 downto 0) := (others => '1');
    begin
        rs1 := signed(a_in);
        rs2 := signed(b_in);
        opcode := instr(6 downto 0);
        funct3 := instr(14 downto 12);
        funct7 := instr(31 downto 25);
        shift_amount := to_integer(unsigned(b_in(4 downto 0)));

        case opcode is
            when "0110011" =>
                case funct3 is
                    when "000" =>
                        if funct7 = "0000000" then
                            exp := std_logic_vector(rs1 + rs2);
                        elsif funct7 = "0000001" then
                            temp := rs1 * rs2;
                            exp := std_logic_vector(temp(31 downto 0));
                        elsif funct7 = "0100000" then
                            exp := std_logic_vector(rs1 - rs2);
                        end if;
                    when "110" =>
                        exp := a_in or b_in;
                    when "111" =>
                        exp := a_in and b_in;
                    when "001" =>
                        exp := std_logic_vector(shift_left(unsigned(a_in), shift_amount));
                    when "101" =>
                        if funct7 = "0000000" then
                            exp := std_logic_vector(shift_right(unsigned(a_in), shift_amount));
                        elsif funct7 = "0100000" then
                            exp := std_logic_vector(shift_right(rs1, shift_amount));
                        end if;
                    when others =>
                        null;
                end case;

            when "0010011" =>
                case funct3 is
                    when "000" =>
                        exp := std_logic_vector(rs1 + rs2);
                    when "100" =>
                        exp := a_in xor b_in;
                    when "110" =>
                        exp := a_in or b_in;
                    when "111" =>
                        exp := a_in and b_in;
                    when "010" =>
                        if rs1 < rs2 then
                            exp := (31 downto 1 => '0') & '1';
                        else
                            exp := (others => '0');
                        end if;
                    when others =>
                        null;
                end case;
            when others =>
                null;
        end case;

        return exp;
    end function;

begin
    dut: alu port map(
        instruction => instruction,
        op1 => A,
        op2 => B,
        result => result
    );

    test_process: process
        procedure check_case(
            constant test_name : in string;
            constant instr : in std_logic_vector(31 downto 0);
            constant a_in : in std_logic_vector(31 downto 0);
            constant b_in : in std_logic_vector(31 downto 0)
        ) is
            variable expected : std_logic_vector(31 downto 0);
        begin
            expected := gt_result(instr, a_in, b_in);
            instruction <= instr;
            A <= a_in;
            B <= b_in;
            wait for 1 ns;
            assert result = expected
                report test_name & " failed: expected=" & to_hstring(expected) & " got=" & to_hstring(result)
                severity error;
        end procedure;

        variable rand_a : std_logic_vector(31 downto 0) := x"12345678";
        variable rand_b : std_logic_vector(31 downto 0) := x"CAFEBABE";
        variable rand_instr : std_logic_vector(31 downto 0);
        variable first_result : std_logic_vector(31 downto 0);
    begin
        report "ALU tests start";

        -- R-type arithmetic
        check_case("R add basic", make_r("0000000", "000"), x"00000001", x"00000002");
        check_case("R add wrap", make_r("0000000", "000"), x"7FFFFFFF", x"00000001");
        check_case("R sub basic", make_r("0100000", "000"), x"00000005", x"00000003");
        check_case("R sub corner", make_r("0100000", "000"), x"80000000", x"00000001");
        check_case("R mul basic", make_r("0000001", "000"), x"00000007", x"00000009");
        check_case("R mul signed", make_r("0000001", "000"), x"FFFFFFFF", x"00000007");

        -- R-type shifts
        check_case("R sll shamt 0", make_r("0000000", "001"), x"80000001", x"00000000");
        check_case("R sll shamt 1", make_r("0000000", "001"), x"80000001", x"00000001");
        check_case("R sll shamt 31", make_r("0000000", "001"), x"00000001", x"0000001F");
        check_case("R srl shamt 0", make_r("0000000", "101"), x"80000000", x"00000000");
        check_case("R srl shamt 1", make_r("0000000", "101"), x"80000000", x"00000001");
        check_case("R srl shamt 31", make_r("0000000", "101"), x"80000000", x"0000001F");
        check_case("R sra shamt 1", make_r("0100000", "101"), x"80000000", x"00000001");
        check_case("R sra shamt 31", make_r("0100000", "101"), x"80000000", x"0000001F");

        -- I-type arithmetic/logic
        check_case("I addi positive", make_i(x"005", "000"), x"00000010", x"00000005");
        check_case("I addi negative", make_i(x"FFB", "000"), x"00000010", x"FFFFFFFB");
        check_case("I xori", make_i(x"00F", "100"), x"12345678", x"00FF00FF");
        check_case("I ori", make_i(x"00F", "110"), x"12340000", x"0000F00F");
        check_case("I andi", make_i(x"00F", "111"), x"FFFF00FF", x"0F0F0F0F");

        -- I-type compares
        check_case("I slti true", make_i(x"001", "010"), x"FFFFFFFF", x"00000001");
        check_case("I slti false", make_i(x"001", "010"), x"00000002", x"00000001");

        -- Decode robustness
        check_case("Invalid opcode", x"FFFFFFFF", x"11111111", x"22222222");
        check_case("Invalid R funct", make_r("1111111", "000"), x"11111111", x"22222222");
        check_case("Unsupported R slt", make_r("0000000", "010"), x"FFFFFFFF", x"00000001");
        check_case("Unsupported R sltu", make_r("0000000", "011"), x"00000001", x"FFFFFFFF");
        check_case("Unsupported I slli", make_i("0000000" & "00001", "001"), x"80000001", x"00000000");
        check_case("Unsupported I srli", make_i("0000000" & "00001", "101"), x"80000000", x"FFFFFFFF");
        check_case("Unsupported I srai", make_i("0100000" & "00001", "101"), x"80000000", x"00000000");
        check_case("Unsupported I sltiu", make_i(x"001", "011"), x"00000001", x"FFFFFFFF");

        -- Combinational responsiveness to A changes
        instruction <= make_r("0000000", "000");
        A <= x"00000011";
        B <= x"00000022";
        wait for 1 ns;
        first_result := result;

        A <= x"00000044";
        wait for 1 ns;
        assert result = gt_result(instruction, A, B)
            report "Combinational update failed when only A changes"
            severity error;
        assert result /= first_result
            report "Result did not change when only A changed"
            severity error;

        -- Combinational responsiveness to B changes
        instruction <= make_r("0000000", "110");
        A <= x"0F0F0F0F";
        B <= x"00000000";
        wait for 1 ns;
        first_result := result;

        B <= x"F0000000";
        wait for 1 ns;
        assert result = gt_result(instruction, A, B)
            report "Combinational update failed when only B changes"
            severity error;
        assert result /= first_result
            report "Result did not change when only B changed"
            severity error;

        -- Randomized GT checks
        for i in 0 to 199 loop
            rand_a := next_rand(rand_a);
            rand_b := next_rand(rand_b);

            case i mod 9 is
                when 0 =>
                    rand_instr := make_r("0000000", "000"); -- add
                when 1 =>
                    rand_instr := make_r("0100000", "000"); -- sub
                when 2 =>
                    rand_instr := make_r("0000001", "000"); -- mul
                when 3 =>
                    rand_instr := make_r("0000000", "001"); -- sll
                when 4 =>
                    rand_instr := make_r("0000000", "101"); -- srl
                when 5 =>
                    rand_instr := make_r("0100000", "101"); -- sra
                when 6 =>
                    rand_instr := make_i(x"001", "000"); -- addi
                when 7 =>
                    rand_instr := make_i(x"00F", "100"); -- xori
                when 8 =>
                    rand_instr := make_i(x"001", "010"); -- slti
                when others =>
                    rand_instr := make_i(x"00F", "111"); -- andi
            end case;

            check_case("Random case " & integer'image(i), rand_instr, rand_a, rand_b);
        end loop;

        report "ALU tests complete";
        std.env.stop;
        wait;
    end process;
end behavior;
