--Adapted from Example 12-15 of Quartus Design and Synthesis handbook
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity memory is
	generic(
		ram_size : integer := 32768;
		mem_delay : time := 1 ns;
		clock_period : time := 1 ns
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
	signal ram_block: mem;
	signal read_address_reg: integer range 0 to ram_size-1;
	signal write_waitreq_reg: std_logic := '1';
	signal read_waitreq_reg: std_logic := '1';
begin
	--This is the main section of the SRAM model
	mem_process: process (clock)
	begin
		--This is a cheap trick to initialize the SRAM in simulation
		if(now < 1 ps)then
			for i in 0 to ram_size-1 loop
				ram_block(i) <= std_logic_vector(to_unsigned(0, 8));
			end loop;
		end if;

		--This is the actual synthesizable SRAM block
		if (clock'event and clock = '1') then
			if (memwrite = '1') then
				ram_block(address) <= writedata;
			end if;
		read_address_reg <= address;
		end if;
	end process;
	readdata <= ram_block(read_address_reg);


	--The waitrequest signal is used to vary response time in simulation
	--Read and write should never happen at the same time.
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
