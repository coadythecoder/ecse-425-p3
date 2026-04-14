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

	constant BYTES_PER_WORD  : integer := 4;
	constant WORDS_PER_BLOCK : integer := 4;
	constant NUM_BLOCKS      : integer := 32;
	constant TAG_SIZE        : integer := 6;
	constant BLOCK_BYTES     : integer := 16;

	-- Address layout (lower 15 bits, bits 1:0 ignored):
	--   bits  3:2 -> word offset (2 bits, 4 words/block)
	--   bits  8:4 -> block index (5 bits, 32 blocks)
	--   bits 14:9 -> tag         (6 bits)

	type word_array  is array(0 to WORDS_PER_BLOCK-1) of std_logic_vector(31 downto 0);
	type cache_block is record
		valid : std_logic;
		dirty : std_logic;
		tag   : std_logic_vector(TAG_SIZE-1 downto 0);
		data  : word_array;
	end record;
	type cache_array is array(0 to NUM_BLOCKS-1) of cache_block;
	type state_type  is (IDLE, CHECK, WRITEBACK, MEM_READ, COMPLETE);

	signal my_cache : cache_array;
	signal state : state_type;

	signal tag_reg : std_logic_vector(TAG_SIZE-1 downto 0);
	signal block_idx_reg : integer range 0 to NUM_BLOCKS-1;
	signal word_offset_reg : integer range 0 to WORDS_PER_BLOCK-1;
	signal write_data_reg : std_logic_vector(31 downto 0);
	signal is_write : boolean;

	signal wb_base_addr : integer range 0 to ram_size-1;

	signal byte_counter : integer range 0 to 15;
	signal m_write_reg : std_logic;
	signal m_read_reg : std_logic;

begin

	process(clock, reset)
		variable word_idx : integer;
		variable byte_in_w : integer;
		variable bit_hi : integer;
		variable bit_lo : integer;
		variable mem_base : integer;
		variable temp_word : std_logic_vector(31 downto 0);
	begin
		if reset = '1' then
			s_waitrequest <= '1';
			s_readdata <= (others => '0');
			state <= IDLE;

			for i in 0 to NUM_BLOCKS-1 loop
				my_cache(i).valid <= '0';
				my_cache(i).dirty <= '0';
				my_cache(i).tag <= (others => '0');
				for j in 0 to WORDS_PER_BLOCK-1 loop
					my_cache(i).data(j) <= (others => '0');
				end loop;
			end loop;

			tag_reg <= (others => '0');
			block_idx_reg <= 0;
			word_offset_reg <= 0;
			write_data_reg <= (others => '0');
			is_write <= false;
			wb_base_addr <= 0;
			byte_counter <= 0;
			m_write_reg <= '0';
			m_read_reg <= '0';

		elsif rising_edge(clock) then
			case state is
				when IDLE =>
					s_waitrequest <= '1';
					if s_read = '1' or s_write = '1' then
						tag_reg <= s_addr(14 downto 9);
						block_idx_reg <= to_integer(unsigned(s_addr(8 downto 4)));
						word_offset_reg <= to_integer(unsigned(s_addr(3 downto 2)));
						is_write <= (s_write = '1');
						if s_write = '1' then
							write_data_reg <= s_writedata;
						end if;
						state <= CHECK;
					end if;
				when CHECK =>
					if my_cache(block_idx_reg).valid = '1' and my_cache(block_idx_reg).tag = tag_reg then
						-- HIT
						if is_write then
							my_cache(block_idx_reg).data(word_offset_reg) <= write_data_reg;
							my_cache(block_idx_reg).dirty <= '1';
						else
							s_readdata <= my_cache(block_idx_reg).data(word_offset_reg);
						end if;
						s_waitrequest <= '0';
						state <= COMPLETE;

					elsif my_cache(block_idx_reg).valid = '1' and my_cache(block_idx_reg).dirty = '1' then
						-- MISS + dirty eviction needed
						-- Snapshot dirty data and compute its memory address NOW,
						-- while my_cache is valid. WRITEBACK uses wb_data / wb_base_addr
						-- so MEM_READ can freely overwrite my_cache(block_idx_reg).
						wb_base_addr <= (to_integer(unsigned(my_cache(block_idx_reg).tag)) * NUM_BLOCKS + block_idx_reg) * BLOCK_BYTES;
						state <= WRITEBACK;
					else
						-- MISS + clean or invalid
						state <= MEM_READ;
					end if;
				when WRITEBACK =>
					if m_write_reg = '0' then
						word_idx := byte_counter / BYTES_PER_WORD;
						byte_in_w := byte_counter mod BYTES_PER_WORD;
						bit_hi := (byte_in_w+1)*8 - 1;
						bit_lo := byte_in_w*8;

						m_addr <= wb_base_addr + byte_counter;
						m_writedata <= my_cache(block_idx_reg).data(word_idx)(bit_hi downto bit_lo);
						m_write_reg <= '1';
					elsif m_waitrequest = '0' then
						m_write_reg <= '0';
						if byte_counter = 15 then
							byte_counter <= 0;
							state <= MEM_READ;
						else
							byte_counter <= byte_counter + 1;
						end if;
					end if;
				when MEM_READ =>
					if m_read_reg = '0' then
						mem_base := (to_integer(unsigned(tag_reg)) * NUM_BLOCKS + block_idx_reg) * BLOCK_BYTES;
						m_addr <= mem_base + byte_counter;
						m_read_reg <= '1';
					elsif m_waitrequest = '0' then
						word_idx := byte_counter / BYTES_PER_WORD;
						byte_in_w := byte_counter mod BYTES_PER_WORD;
						bit_hi := (byte_in_w+1)*8 - 1;
						bit_lo := byte_in_w*8;

						-- temp_word is a variable: update is immediate this cycle
						temp_word := my_cache(block_idx_reg).data(word_idx);
						temp_word(bit_hi downto bit_lo) := m_readdata;
						my_cache(block_idx_reg).data(word_idx) <= temp_word;

						m_read_reg <= '0';
						if byte_counter = 15 then
							my_cache(block_idx_reg).valid <= '1';
							my_cache(block_idx_reg).dirty <= '0';
							my_cache(block_idx_reg).tag <= tag_reg;
							byte_counter <= 0;

							if is_write then
								-- Write-miss: stamp in the written word (wins over loop above)
								my_cache(block_idx_reg).data(word_offset_reg) <= write_data_reg;
								my_cache(block_idx_reg).dirty <= '1';
							else
								-- Read-miss: drive s_readdata now so testbench sees it
								-- when waitrequest falls this same cycle.
								-- temp_word holds the correct value for word_idx (last fetched).
								-- For other words, read directly from my_cache — those bytes
								-- were committed in earlier iterations via signal assignment
								-- and have settled (this is byte_counter=15, those were earlier).
								if word_idx = word_offset_reg then
									s_readdata <= temp_word;
								else
									s_readdata <= my_cache(block_idx_reg).data(word_offset_reg);
								end if;
							end if;
							state <= COMPLETE;
							s_waitrequest <= '0';
						else
							byte_counter <= byte_counter + 1;
						end if;
					end if;
				when COMPLETE =>
					if not is_write then
						s_readdata <= my_cache(block_idx_reg).data(word_offset_reg);
					end if;
					is_write <= false;
					s_waitrequest <= '1';
					state <= IDLE;
			end case;
		end if;
	end process;

	m_write <= m_write_reg;
	m_read <= m_read_reg;

end arch;