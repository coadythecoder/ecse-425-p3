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
-- constants
	constant WORD_SIZE : integer := 32;
	constant WORDS_IN_BLOCK : integer := 4;
	constant BLOCKS_IN_CACHE : integer := 32;
	constant VALID_BIT_SIZE : integer := 1;
	constant DIRTY_BIT_SIZE : integer := 1;
	constant TAG_SIZE : integer := 8; -- 8 == 15 (lower bits considered) - 2 (byte offset) - 5 (block offset)
-- internal types
	type cache_frame is std_logic_Vector(DIRTY_BIT_SIZE + VALID_BIT_SIZE + TAG_SIZE + WORD_SIZE - 1 downto 0);
	type cache_block is array(WORDS_IN_BLOCK - 1 downto 0) of cache_frame;
	type cache_array is array(BLOCKS_IN_CACHE - 1 downto 0) of cache_block;
-- signals
	signal my_cache : cache_array;
begin
	cache_process : process(clock)
	begin
		-- if rising_edge


		-- handle read

		-- handle write

	end process;
-- make circuits here

end arch;