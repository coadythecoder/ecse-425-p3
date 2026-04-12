--Adapted from Example 12-15 of Quartus Design and Synthesis handbook
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity memory is
	generic(
		ram_size : integer := 32768;
		mem_delay : time := 1 ns;
		clock_period : time := 1 ns;
		writable : boolean := true
	);
	port (
		clock: IN std_logic;
		writedata: IN std_logic_vector (31 downto 0);
		address: in integer range 0 to ram_size-1;
		memwrite: in std_logic;
		memread: in std_logic;
		readdata: out std_logic_vector (31 downto 0);
		waitrequest: out std_logic
	);
end memory;

architecture rtl of memory is
	type mem is array(ram_size-1 downto 0) of std_logic_vector(31 downto 0);
	signal ram_block: mem := (others => (others => '0'));
	signal read_address_reg: integer range 0 to ram_size-1 := 0;
	signal write_waitreq_reg: std_logic := '1';
	signal read_waitreq_reg: std_logic := '1';
begin

	-- Write on rising edge; skipped entirely when writable=false
	gen_write: if writable generate
		write_proc: process (clock)
		begin
			if rising_edge(clock) then
				if memwrite = '1' then
					ram_block(address) <= writedata;
				end if;
			end if;
		end process;
	end generate;

	-- Read address latched on falling edge; readdata is combinatorial
	read_proc: process (clock)
	begin
		if falling_edge(clock) then
			read_address_reg <= address;
		end if;
	end process;

	readdata <= ram_block(read_address_reg);


	-- waitrequest signal used to vary response time in simulation
	-- Read and write should never happen at the same time.
	waitreq_w_proc: process (memwrite)
	begin
		if(memwrite'event and memwrite = '1')then
			write_waitreq_reg <= '0' after mem_delay, '1' after mem_delay + clock_period;
		end if;
	end process;

	waitreq_r_proc: process (memread)
	begin
		if(memread'event and memread = '1')then
			read_waitreq_reg <= '0' after mem_delay, '1' after mem_delay + clock_period;
		end if;
	end process;
	waitrequest <= write_waitreq_reg and read_waitreq_reg;


end rtl;
