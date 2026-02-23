library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cache is
generic(
	ram_size : INTEGER := 32768
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
	constant TAG_SIZE : integer := 6; 
	-- address (31:0, byte addressable) can split in the following way using the lower 15 bits
	-- 1:0 ignored since memory accesses are assumed to be word-addressable (multiple of four so bits 1:0 always 0)
	-- 3:2 offset within the block i.e. which of the four words in the block is the one we want
	-- 8:4 block address, 8:4 is 5 total bits corresponding to the 2^5=32 total cache blocks
	-- 14:9 (6 bits total) is the remaining spcace and is thus the tag

-- internal types
	type word_array is array(WORDS_IN_BLOCK - 1 downto 0) of std_logic_vector(WORD_SIZE - 1 downto 0);
	type cache_block is record 
		valid : std_logic;
		dirty : std_logic;
		tag : std_logic_vector(TAG_SIZE - 1 downto 0);
		data : word_array;
	end record;
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
	signal cur_block_index : integer := -1;
begin
	cache_process : process(clock, reset)
	-- variable declaration
	variable temp_tag : std_logic_vector(TAG_SIZE - 1 downto 0);
	variable temp_block : cache_block;
	begin
		-- insert some logic to initialize all the cache blocks in the my_cache as well as 
		if reset='1' then
			state <= IDLE;
			-- intialize the empty cache, all flags set to zero too
			for i in 0 to BLOCKS_IN_CACHE-1 loop
				my_cache(i).valid <= '0';
				my_cache(i).dirty <= '0';
				my_cache(i).tag <= (others => '0');
				my_cache(i).data <= (others => '0');
			end loop;
			wait_request_reg <= '1';
			cached_checked := false;
		elsif rising_edge(clock) then
			case state is
				when IDLE =>
					if wait_request_reg = '0' then
						-- since it should only be zero for one clock cycle
						wait_request_reg <= '1';
					
					-- if read or write is 1 then get things ready and transition to appropriate state
					elsif s_read = '1' or s_write = '1' then
						address_reg <= s_addr;
						cur_block_index <= to_integer(unsigned(s_addr(6 downto 2))) mod BLOCKS_IN_CACHE;
						if s_read = '1' then
							state <= READ_INIT;
						elsif s_write = '1' then
							state <= WRITE_INIT;
							write_data_reg <= s_writedata;
						end if;
					end if;
				when READ_INIT => 
					temp_tag := --;
					temp_block := --;
					if temp_block.tag = temp_tag and  temp_block.valid = '1' then -- hit
						s_readdata <= temp.data;
						wait_request_reg <= '0';
					else -- miss
						state <= READ_WAIT;
					end if;
				when WRITE_INIT =>
					if my_cache(temp_block_index).tag = temp_tag and (my_cache)then -- hit
						my_cache(temp_block_index).data 
					end if;
				when READ_WAIT => 
					-- wait for memory to assert 0 on m_waitrequest, then put it into corresponding cache block
				when WRITE_WAIT => 
					-- wait for memory to assert 0 on m_waitrequest, put into corresponding cache block, modify in cache
			end case;	
		end if;
	end process;

	s_waitrequest <= wait_request_reg;

end arch;