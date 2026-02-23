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
	constant OFFSET_START : integer := 3;
	constant OFFSET_END : integer := 2;
	-- 8:4 block address, 8:4 is 5 total bits corresponding to the 2^5=32 total cache blocks
	constant BLOCK_ADDR_START : integer := 8;
	constant BLOCK_ADDR_END : integer := 4;
	-- 14:9 (6 bits total) is the remaining spcace and is thus the tag
	constant TAG_START : integer := 14;
	constant TAG_END : integer := 9;

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
	signal wait_request_reg : std_logic; -- register for keeping track of cache's s_waitrequest
	signal state : state_type; -- current state
	-- register for holding onto the address we care about even if the input changes during execution
	signal address_reg : std_logic_vector(WORD_SIZE - 1 downto 0); 
	-- register for holding onto data to be written
	signal write_data_reg : std_logic_vector(WORD_SIZE - 1 downto 0);
	-- signal to keep track of current block index to avoid having to recompute every time (keeps things a little tidy)
	signal cur_block_index : integer;
	-- signal to keep track of byte index (relative to base address) loaded from memory
	signal cur_byte_index: integer;
begin
	cache_process : process(clock, reset)
	-- variable declaration
	variable temp_tag : std_logic_vector(TAG_SIZE - 1 downto 0);
	variable temp_block : cache_block;
	variable temp_offset : integer;
	variable temp_word_index : integer;
	variable t_rel_byte_i : integer; -- temporary relative byte index
	begin
		if reset='1' then
			-- intialize everything to default values
			state <= IDLE;
			for i in 0 to BLOCKS_IN_CACHE-1 loop
				my_cache(i).valid <= '0';
				my_cache(i).dirty <= '0';
				my_cache(i).tag <= (others => '0');
				for i in 0 to WORDS_IN_BLOCK - 1 loop
					current_block.data(i) := (others => '0');
				end loop;
			end loop;
			wait_request_reg <= '1';
			address_reg <= (others => '0');
			write_data_reg <= (others => '0');
			cur_byte_index <= 0;
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
					temp_tag := address_reg(TAG_START downto TAG_END);
					temp_block := my_cache(cur_block_index);
					if temp_block.valid = '1' and temp_block.tag = temp_tag then
						-- hit
						temp_offset := to_integer(unsigned(address_reg(OFFSET_START downto OFFSET_END)));
						s_readdata <= temp_block.data(temp_offset);
						wait_request_reg <= '0'; -- this will get reset to 1 at the next clock cycle, see IDLE state logic
					else -- miss
						-- handle write back
						
						-- m_addr is an integer not a vector for some reason so gotta convert
						m_addr <= to_integer(unsigned(address_reg(TAG_START downto 0)));
						m_read <= '1';
						state <= READ_WAIT;
					end if;
				when WRITE_INIT =>
					temp_tag := address_reg(TAG_START downto TAG_END);
					temp_block := my_cache(cur_block_index);
					if temp_block.valid = '1' then

					else
						-- handle write-back
					end if;
				when READ_WAIT => 
					if m_waitrequest = '0' then
						temp_word_index := cur_byte_index / 4; -- 4 bytes in a word
						t_rel_byte_i := cur_byte_index mod 4;
						my_cache(cur_block_index).data(temp_word_index)(((t_rel_byte_i+1)*8)-1 downto t_rel_byte_i*8) <= m_readdata; 
						
						if cur_byte_index = 15 then
							cur_byte_index = 0;
							wait_request_reg <= '0';
							temp_offset := to_integer(unsigned(address_reg(OFFSET_START downto OFFSET_END)));
							my_cache(cur_block_index).tag <= address_reg(TAG_START downto TAG_END);
							my_cache(cur_block_index).valid <= '1';
							my_cache(cur_block_index).dirty <= '0';
							s_readata = my_cache(cur_block_index).data(temp_offset);
							state <= IDLE;
						end if;
						cur_byte_index <= cur_byte_index + 1;
					end if;
					-- if the waitrequest is still 1, check again next cycle
				when WRITE_WAIT => 
					-- wait for memory to assert 0 on m_waitrequest, put into corresponding cache block, modify in cache
			end case;	
		end if;
	end process;

	s_waitrequest <= wait_request_reg;

end arch;