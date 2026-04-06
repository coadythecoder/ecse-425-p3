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

	-- CONSTANTS go here: fixed compile-time values, private to this architecture. ex: constant WORD_SIZE : integer := 32;
	constant BYTE_SIZE : integer := 8;
	constant WORD_SIZE : integer := 32;
	constant WORDS_PER_BLOCK : integer := 4;
	constant NUM_BLOCKS : integer := 32;
	constant TAG_SIZE : integer := 6;
	constant MEM_ADDR_SIZE : integer := 15;
	-- address (31:0, byte addressable) can be split in the following way using the lower 15 bits
	-- 1->0 ignored since memory accesses are assumed to be word-addressable (multiple of four bits, so bits 1:0 always 0)
	-- 4 words per block, so word offset is 2 bits, corresponding to bits to 3->2
	constant WORD_OFFSET_START : integer := 3;
	constant WORD_OFFSET_END : integer := 2;
	-- 32 blocks, so block offset is 5 bits, corresponding to bits 8->4
	constant BLOCK_OFFSET_START : integer := 8;
	constant BLOCK_OFFSET_END : integer := 4;
	-- 14->9 are the remaining bits, and thus the tag size is 6 bits (14-9+1=6)
	constant TAG_START : integer := MEM_ADDR_SIZE - 1;
	constant TAG_END : integer := 9;

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
	signal my_cache : cache_array; -- instantiated cache
	signal state : state_type; -- state variable
	signal addr_reg : std_logic_vector(MEM_ADDR_SIZE-1 downto 0); -- register to store 15 lower bits of given address
	signal tag_reg : std_logic_vector(TAG_SIZE-1 downto 0); -- register to store tag portion of address
	signal block_offset_reg : integer; -- register to store block index of address
	signal word_offset_reg : integer; -- register to store word offset of address
	signal write_data_reg : std_logic_vector(31 downto 0); -- register to store data to be written
	signal is_write_request : boolean; -- write flag
	signal is_read_request : boolean; -- read flag
	signal target_block : cache_block; -- to hold the value of the target block
	signal byte_counter : integer; -- for use in WRITEBACK and MEM_READ
	signal m_write_reg : std_logic; -- to drive m_write
	signal m_read_reg : std_logic; -- to drive m_read

begin

	-- PROCESSES go here: clocked (sequential) or combinational logic blocks. ex: process(clock, reset) begin ... end process;
	process(clock, reset)
		-- VARIABLES go here, inside the process, before the begin keyword
		variable word_index : integer;
		variable byte_start_index : integer;
		variable byte_end_index : integer;
		variable base_addr : integer;
	begin
		if reset = '1' then
			s_waitrequest <= '1';
			
			state <= IDLE;

			-- initialize cache
			for i in 0 to NUM_BLOCKS-1 loop
				my_cache(i).valid <= '0';
				my_cache(i).dirty <= '0';
				my_cache(i).tag <= (others => '0');
				for j in 0 to WORDS_PER_BLOCK-1 loop
					my_cache(i).data(j) <= (others => '0');
				end loop;
			end loop;

			-- reset other internal signals to 0
			addr_reg <= (others => '0');
			tag_reg <= (others => '0');
			block_offset_reg <= 0;
			word_offset_reg <= 0;
			write_data_reg <= (others => '0');
			is_write_request <= false;
			is_read_request <= false;
			
			target_block.valid <= '0';
			target_block.dirty <= '0';
			target_block.tag <= (others => '0');
			for i in 0 to WORDS_PER_BLOCK-1 loop
				target_block.data(i) <= (others => '0');
			end loop;

			byte_counter <= 0;

			word_index := 0;

		elsif rising_edge(clock) then
			case state is
				when IDLE =>
					s_waitrequest <= '1';
					if (s_read = '1') or (s_write = '1') then
						addr_reg <= s_addr(MEM_ADDR_SIZE-1 downto 0);
						tag_reg <= s_addr(TAG_START downto TAG_END);
						block_offset_reg <= to_integer(unsigned(s_addr(BLOCK_OFFSET_START downto BLOCK_OFFSET_END)));
						word_offset_reg <= to_integer(unsigned(s_addr(WORD_OFFSET_START downto WORD_OFFSET_END)));
						
						if s_write = '1' then
							write_data_reg <= s_writedata;
							is_write_request <= true;
						else
							is_read_request <= true;
						end if;
						
						state <= CHECK;
						s_waitrequest <= '0'; -- then set high in CHECK. does this actually follow the standard?
					end if;
				when CHECK =>
					s_waitrequest <= '1';
					target_block <= my_cache(block_offset_reg);
					if target_block.valid = '1' then
						if target_block.tag = tag_reg then
							if is_write_request then
								target_block.data(word_offset_reg) <= write_data_reg;
							else -- is read_request
								s_readdata <= target_block.data(word_offset_reg);
							end if;
							state <= COMPLETE;
						elsif target_block.dirty = '1' then
							state <= WRITEBACK;
						else
							state <= MEM_READ;
						end if;
					else
						state <= MEM_READ;
					end if;
				when WRITEBACK =>
					if m_write_reg = '0' then
						base_addr := to_integer(unsigned(addr_reg(MEM_ADDR_SIZE-1 downto 2)));
						word_index := byte_counter / (WORD_SIZE/BYTE_SIZE);
						-- endianness does not matter as long as we're being consistent, and thus i am choosing little-endian
						byte_start_index := (byte_counter+1)*8 - 1;
						byte_end_index := (byte_counter)*8;

						m_addr <= base_addr + byte_counter;
						m_writedata <= target_block.data(word_index)(byte_start_index downto byte_end_index);
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
						base_addr := to_integer(unsigned(addr_reg(MEM_ADDR_SIZE-1 downto 2)));

						m_addr <= base_addr + byte_counter;
						m_read_reg <= '1';
					elsif m_waitrequest = '0' then
						word_index := byte_counter / (WORD_SIZE/BYTE_SIZE);
						-- endianness does not matter as long as we're being consistent, and thus i am choosing little-endian
						byte_start_index := (byte_counter+1)*8 - 1;
						byte_end_index := (byte_counter)*8;

						target_block.data(word_index)(byte_start_index downto byte_end_index) <= m_readdata;

						m_read_reg <= '0';
						if byte_counter = 15 then
							target_block.valid <= '1';
							target_block.dirty <= '0';
							target_block.tag <= tag_reg;
							my_cache(block_offset_reg) <= target_block;

							byte_counter <= 0;
							state <= COMPLETE;
						else
							byte_counter <= byte_counter + 1;
						end if;
					end if;

				when COMPLETE =>
					if is_read_request then
						s_readdata <= target_block.data(word_offset_reg);
					else 
						my_cache(block_offset_reg).data(word_offset_reg) <= s_writedata;
						my_cache(block_offset_reg).dirty <= '1';
					end if;
					s_waitrequest <= '0';
					state <= IDLE;
			end case;
		end if;
	end process;

	-- CONCURRENT SIGNAL ASSIGNMENTS go here: permanent connections that always drive a signal, outside any process. ex: m_read <= m_read_reg;
	m_write <= m_write_reg;
	m_read <= m_read_reg;

end arch;