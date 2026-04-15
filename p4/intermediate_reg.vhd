library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity if_id_reg is
    port (
        clk        : in  std_logic;
        reset      : in  std_logic;
        enable     : in  std_logic;
        ir_in   : in  std_logic_vector(31 downto 0);
        pc_in      : in  std_logic_vector(31 downto 0);
        ir_out  : out std_logic_vector(31 downto 0);
        pc_out     : out std_logic_vector(31 downto 0)
    );
end if_id_reg;

architecture behavioral of if_id_reg is
    signal ir_reg : std_logic_vector(31 downto 0);
    signal pc_reg    : std_logic_vector(31 downto 0);
begin

    process(clk, reset)
    begin
        if reset = '1' then
            ir_reg <= (others => '0');
            pc_reg    <= (others => '0');

        elsif rising_edge(clk) then
            if enable = '1' then
                ir_reg <= ir_in;
                pc_reg    <= pc_in;
            end if;
        end if;
    end process;

    ir_out <= ir_reg;
    pc_out    <= pc_reg;

end behavioral;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
entity id_ex_reg is
    port (
        clk	: in  std_logic;
        reset	: in  std_logic;
        enable	: in  std_logic;
        npc_in	: in  std_logic_vector(31 downto 0);
        a_in	: in  std_logic_vector(31 downto 0);
        b_in	: in  std_logic_vector(31 downto 0);
        immval_in	: in  std_logic_vector(31 downto 0);
        rd_in	: in  std_logic_vector(4 downto 0);
        ir_in   : in  std_logic_vector(31 downto 0);
        mux_a_select_in   : in  std_logic;
        mux_b_select_in   : in  std_logic;
        npc_out	: out  std_logic_vector(31 downto 0);
        a_out	: out  std_logic_vector(31 downto 0);
        b_out	: out  std_logic_vector(31 downto 0);
        immval_out	: out  std_logic_vector(31 downto 0);
        rd_out	: out  std_logic_vector(4 downto 0);
        ir_out  : out std_logic_vector(31 downto 0);
        mux_a_select_out   : out  std_logic;
        mux_b_select_out   : out  std_logic
    );
end id_ex_reg;

architecture behavioral of id_ex_reg is
    signal npc_reg	: std_logic_vector(31 downto 0);
    signal a_reg	: std_logic_vector(31 downto 0);
    signal b_reg	: std_logic_vector(31 downto 0);
    signal immval_reg	: std_logic_vector(31 downto 0);
    signal rd_reg	: std_logic_vector(4 downto 0);
    signal ir_reg : std_logic_vector(31 downto 0);
    signal mux_a_select_reg : std_logic;
    signal mux_b_select_reg : std_logic;
begin

    process(clk, reset)
    begin
        if reset = '1' then
            npc_reg	<= (others => '0');
            a_reg	<= (others => '0');
            b_reg	<= (others => '0');
            immval_reg	<= (others => '0');
            rd_reg	<= (others => '0');
            ir_reg	<= (others => '0');
            mux_a_select_reg	<= '0';
            mux_b_select_reg	<= '0';

        elsif rising_edge(clk) then
            if enable = '1' then
                npc_reg	<= npc_in;
                a_reg	<= a_in;
                b_reg	<= b_in;
                immval_reg	<= immval_in;
                rd_reg	<= rd_in;
                ir_reg  <=  ir_in;
                mux_a_select_reg    <= mux_a_select_in;
                mux_b_select_reg    <= mux_b_select_in;
            end if;
        end if;
    end process;

    npc_out <=  npc_reg;
    a_out   <=  a_reg;
    b_out   <=  b_reg;
    immval_out  <=  immval_reg;
    rd_out  <=  rd_reg;
    ir_out  <=  ir_reg;
    mux_a_select_out    <=  mux_a_select_reg;
    mux_b_select_out    <=  mux_b_select_reg;
end behavioral;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
entity ex_mem_reg is
    port (
        clk	: in  std_logic;
        reset	: in  std_logic;
        enable	: in  std_logic;
        mux_pc_select_in	: in  std_logic;
        aluout_in	: in  std_logic_vector(31 downto 0);
        b_in	: in  std_logic_vector(31 downto 0);
        rd_in	: in  std_logic_vector(4 downto 0);
        ir_in   : in  std_logic_vector(31 downto 0);
        npc_in	: in  std_logic_vector(31 downto 0);
        mux_pc_select_out	: out  std_logic;
        aluout_out	: out  std_logic_vector(31 downto 0);
        b_out	: out  std_logic_vector(31 downto 0);
        rd_out	: out  std_logic_vector(4 downto 0);
        ir_out   : out  std_logic_vector(31 downto 0);
        npc_out	: out  std_logic_vector(31 downto 0)
    );
end ex_mem_reg;

architecture behavioral of ex_mem_reg is
    signal mux_pc_select_reg	: std_logic;
    signal aluout_reg	: std_logic_vector(31 downto 0);
    signal b_reg	: std_logic_vector(31 downto 0);
    signal rd_reg	: std_logic_vector(4 downto 0);
    signal ir_reg   : std_logic_vector(31 downto 0);
    signal npc_reg	: std_logic_vector(31 downto 0);
begin

    process(clk, reset)
    begin
        if reset = '1' then
            -- Default to sequential PC path right after reset.
            mux_pc_select_reg <= '1';
            aluout_reg <= (others => '0');
            b_reg <= (others => '0');
            rd_reg <= (others => '0');
            ir_reg <= (others => '0');
            npc_reg	<= (others => '0');

        elsif rising_edge(clk) then
            if enable = '1' then
                mux_pc_select_reg	<= mux_pc_select_in;
                aluout_reg	<= aluout_in;
                b_reg	<= b_in;
                rd_reg	<= rd_in;
                ir_reg  <=  ir_in;
                npc_reg	<= npc_in;
            end if;
        end if;
    end process;

    mux_pc_select_out   <=  mux_pc_select_reg;
    aluout_out  <=  aluout_reg;
    b_out   <=  b_reg;
    rd_out  <=  rd_reg;
    ir_out  <=  ir_reg;
    npc_out <=  npc_reg;
end behavioral;


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
entity mem_wb_reg is
    port (
        clk	: in  std_logic;
        reset	: in  std_logic;
        enable	: in  std_logic;
        regwrite_in	: in  std_logic;
        mux_write_select_in	: in  std_logic_vector(1 downto 0);
        aluout_in	: in  std_logic_vector(31 downto 0);
        mem_ldr_result_in	: in  std_logic_vector(31 downto 0);
        rd_in	: in  std_logic_vector(4 downto 0);
        npc_in	: in  std_logic_vector(31 downto 0);
        regwrite_out	: out  std_logic;
        mux_write_select_out	: out  std_logic_vector(1 downto 0);
        aluout_out	: out  std_logic_vector(31 downto 0);
        mem_ldr_result_out	: out  std_logic_vector(31 downto 0);
        rd_out	: out  std_logic_vector(4 downto 0);
        npc_out	: out  std_logic_vector(31 downto 0)

    );
end mem_wb_reg;

architecture behavioral of mem_wb_reg is
    signal regwrite_reg	: std_logic;
    signal mux_write_select_reg	: std_logic_vector(1 downto 0);
    signal aluout_reg	: std_logic_vector(31 downto 0);
    signal mem_ldr_result_reg	: std_logic_vector(31 downto 0);
    signal rd_reg	: std_logic_vector(4 downto 0);
    signal npc_reg	: std_logic_vector(31 downto 0);
begin

    process(clk, reset)
    begin
        if reset = '1' then
            regwrite_reg	<= '0';
            mux_write_select_reg	<= (others => '0'); --should this be the default write select value?
            aluout_reg	<= (others => '0');
            mem_ldr_result_reg	<= (others => '0');
            rd_reg	<= (others => '0');
            npc_reg	<= (others => '0');

        elsif rising_edge(clk) then
            if enable = '1' then
                regwrite_reg	<= regwrite_in;
                mux_write_select_reg	<= mux_write_select_in;
                aluout_reg	<= aluout_in;
                rd_reg	<= rd_in;
                mem_ldr_result_reg  <=  mem_ldr_result_in;
                npc_reg	<= npc_in;
            end if;
        end if;
    end process;

    regwrite_out   <=  regwrite_reg;
    mux_write_select_out  <=  mux_write_select_reg;
    aluout_out   <=  aluout_reg;
    rd_out  <=  rd_reg;
    mem_ldr_result_out  <=  mem_ldr_result_reg;
    npc_out <=  npc_reg;
end behavioral;


