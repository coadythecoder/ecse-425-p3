library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cache is
generic(
	ram_size : INTEGER := 32768;
);
port(
	clock : in std_logic;
	reset : in std_logic;
	
	-- Avalon interface --
	s_addr : in std_logic_vector (31 downto 0);
	s_read : in std_logic;
	s_readdata : out std_logic_vector (31 downto 0);
	s_write : in std_logic;
	s_writedata : in std_logic_vector (31 downto 0);
	s_waitrequest : out std_logic; 
    
	m_addr : out integer range 0 to ram_size-1;
	m_read : out std_logic;
	m_readdata : in std_logic_vector (7 downto 0);
	m_write : out std_logic;
	m_writedata : out std_logic_vector (7 downto 0);
	m_waitrequest : in std_logic
);
end cache;

architecture arch of cache is

	-- CONSTANTS go here: fixed compile-time values, private to this architecture. ex: constant WORD_SIZE : integer := 32;
	constant WORD_SIZE : integer := 32;
	constant WORDS_PER_BLOCK : integer := 4;
	constant NUM_BLOCKS : integer := 32;

	-- TYPES go here: custom array, record, or enum types used by signals below. ex: type state_type is (IDLE, CHECK, WRITEBACK);
	type word_array is array(WORDS_PER_BLOCK-1 downto 0) of std_logic_vector(WORD_SIZE-1 downto 0);
	type cache_block is record
		valid : std_logic;
		dirty : std_logic;
		tag   : std_logic_vector(TAG_SIZE-1 downto 0);
		data  : word_array;
	end record;
	type cache_array is array(NUM_BLOCKS-1 downto 0) of cache_block;
	type state_type is (IDLE, CHECK, WRITEBACK, MEM_READ, COMPLETE);
	
	-- INTERNAL SIGNALS go here: wires that connect things inside the architecture, including FSM state and shadow registers for outputs. ex: signal state : state_type;  signal m_read_reg : std_logic;
	signal my_cache : cache_array;
	signal state : state_type;

begin

	-- PROCESSES go here: clocked (sequential) or combinational logic blocks. ex: process(clock, reset) begin ... end process;
	process(clock, reset)
		-- VARIABLES go here, inside the process, before the begin keyword

	begin
		if reset = '1' then
			-- handle reset
		elsif rising_edge(clock) then
			case state is
				when IDLE =>
				when CHECK =>
				when WRITEBACK =>
				when MEM_READ =>
				when COMPLETE =>
			end case;
		end if;
	end process;

	-- CONCURRENT SIGNAL ASSIGNMENTS go here: permanent connections that always drive a signal, outside any process. ex: m_read <= m_read_reg;

end arch;