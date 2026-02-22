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
	-- type cache_frame is std_logic_Vector(DIRTY_BIT_SIZE + VALID_BIT_SIZE + TAG_SIZE + WORD_SIZE - 1 downto 0);
	type cache_line is record 
		valid : std_logic;
		dirty : std_logic;
		tag : std_logic_vector(TAG_SIZE - 1 downto 0);
		data : std_logic_vector(WORD_SIZE - 1 downto 0);
	end record;
	type cache_block is array(WORDS_IN_BLOCK - 1 downto 0) of cache_frame;
	type cache_array is array(BLOCKS_IN_CACHE - 1 downto 0) of cache_block;
	
	type state_type is (
		IDLE, 
		READ_INIT, 
		WRITE_INIT, 
		READ_WAIT, 
		WRITE_WAIT
	);
	
-- internal signals
	signal my_cache : cache_array;
	signal wait_request_reg : std_logic := '1';
	signal state : state_type;
	signal address_reg : std_logic_vector(WORD_SIZE - 1 downto 0);
	signal write_data_reg : std_logic_vector(WORD_SIZE - 1 downto 0);
begin
-- make circuits here
	cache_process : process(clock, reset)
	-- variables
	variable block_index : integer := 0;
	begin
		-- insert some logic to initialize all the cache blocks in the my_cache as well as 
		if reset='1' then
			state <= IDLE;
			for i in 0 to BLOCKS_IN_CACHE-1 loop
				my_cache(i).valid <= '0';
				my_cache(i).dirty <= '0';
				my_cache(i).tag   <= (others => '0');
				my_cache(i).data  <= (others => '0');
			end loop;
		elsif rising_edge(clock) then
			case state is
				when IDLE =>
					if wait_request_reg = '0' then
						wair_request_reg <= '1';
					elsif s_read = '1' then
						state <= READ_INIT;
						address_reg <= s_addr;
					elsif s_write = '1' then
						state <= WRITE_INIT;
						address_reg <= s_addr;
						write_data_reg <= s_write_data;
					end if;
				when READ_INIT => 
					-- 
				when READ_WAIT => 
					--
				when WRITE_INIT =>
					--
				when WRITE_WAIT => 
					-- 
			end case;	
		end if;
	end process;

	wait_request_process : process(clock)
	begin
		if state = READ_COMPLETE or state = WRITE_COMPLETE then
			wait_request_reg <= '0';
		else
			wait_request_reg <= '1';
		end if;
	end process;

end arch;