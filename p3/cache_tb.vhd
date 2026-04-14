library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cache_tb is
end cache_tb;

architecture behavior of cache_tb is

component cache is
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
end component;

component memory is 
GENERIC(
    ram_size : INTEGER := 32768;
    mem_delay : time := 10 ns;
    clock_period : time := 1 ns
);
PORT (
    clock: IN STD_LOGIC;
    writedata: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
    address: IN INTEGER RANGE 0 TO ram_size-1;
    memwrite: IN STD_LOGIC;
    memread: IN STD_LOGIC;
    readdata: OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
    waitrequest: OUT STD_LOGIC
);
end component;
    
-- test signals 
signal reset : std_logic := '0';
signal clk : std_logic := '0';
constant clk_period : time := 1 ns;

signal s_addr : std_logic_vector (31 downto 0);
signal s_read : std_logic;
signal s_readdata : std_logic_vector (31 downto 0);
signal s_write : std_logic;
signal s_writedata : std_logic_vector (31 downto 0);
signal s_waitrequest : std_logic;

signal m_addr : integer range 0 to 2147483647;
signal m_read : std_logic;
signal m_readdata : std_logic_vector (7 downto 0);
signal m_write : std_logic;
signal m_writedata : std_logic_vector (7 downto 0);
signal m_waitrequest : std_logic;
signal test_num : integer;

-- -----------------------------------------------------------------------
-- Memory initialization pattern (from memory.vhd):
--   mem(i) := std_logic_vector(to_unsigned(i mod 256, 8))
--
-- The cache uses LITTLE-ENDIAN byte assembly:
--   word at byte addr A = mem(A+3) & mem(A+2) & mem(A+1) & mem(A)
--                       (bits 31..24)  (23..16)   (15..8)   (7..0)
--
-- Address 0x00000000  -> block base = 0
--   word0 (addr 0):  bytes 03,02,01,00 -> 0x03020100
--   word1 (addr 4):  bytes 07,06,05,04 -> 0x07060504
--   word2 (addr 8):  bytes 0B,0A,09,08 -> 0x0B0A0908
--   word3 (addr 12): bytes 0F,0E,0D,0C -> 0x0F0E0D0C
--
-- Address 512 (=0x200): 512 mod 256 = 0, same byte pattern as addr 0
--   word0 (addr 512): 0x03020100
--   word1 (addr 516): 0x07060504
-- -----------------------------------------------------------------------

begin

-- Connect the components which we instantiated above to their
-- respective signals.
dut: cache 
port map(
    clock => clk,
    reset => reset,

    s_addr => s_addr,
    s_read => s_read,
    s_readdata => s_readdata,
    s_write => s_write,
    s_writedata => s_writedata,
    s_waitrequest => s_waitrequest,

    m_addr => m_addr,
    m_read => m_read,
    m_readdata => m_readdata,
    m_write => m_write,
    m_writedata => m_writedata,
    m_waitrequest => m_waitrequest
);

MEM : memory
port map (
    clock => clk,
    writedata => m_writedata,
    address => m_addr,
    memwrite => m_write,
    memread => m_read,
    readdata => m_readdata,
    waitrequest => m_waitrequest
);
                

clk_process : process
begin
  clk <= '0';
  wait for clk_period/2;
  clk <= '1';
  wait for clk_period/2;
end process;

test_process : process
begin
    -- ----------------------------------------------------------------
    -- Reset / initialisation
    -- ----------------------------------------------------------------
    report "Initializing cache";
    test_num <= 0;
    s_read  <= '0';
    s_write <= '0';
    s_addr  <= (others => '0');
    s_writedata <= (others => '0');
    reset <= '1';
    wait for clk_period;
    reset <= '0';
    wait for clk_period;

    assert (s_waitrequest = '1' and m_waitrequest = '1')
        report "[INIT] waitrequest should both be '1' after reset" severity error;
    report "Initialization successful";

    -- ----------------------------------------------------------------
    -- Test #1 : Read + Invalid
    --   Cache is cold; block 0 is invalid.
    --   Cache must fetch from memory.
    --   Memory bytes 0..3 = 00 01 02 03 => word = 0x00010203 = 66051
    -- ----------------------------------------------------------------
    report "Test #1: Read + Invalid";
    test_num <= 1;
    wait until rising_edge(clk);
    s_read <= '1';
    s_addr <= std_logic_vector(to_unsigned(0, 32));
    wait until falling_edge(s_waitrequest) for 400 ns;
    assert s_waitrequest = '0'
        report "[T1] TIMEOUT: cache never de-asserted waitrequest" severity error;

    assert s_readdata = x"03020100"
        report "[T1] Expected 0x03020100, got 0x" & to_hstring(s_readdata)
        severity error;
    report "[T1] Read 0x" & to_hstring(s_readdata) &
           "  (expected 0x03020100)";

    wait until rising_edge(clk);
    s_read <= '0';
    wait for clk_period;

    -- ----------------------------------------------------------------
    -- Test #2 : Read + Valid + Not Dirty + Equal Tag
    --   Same address 0, block now valid and clean from Test #1.
    --   Should be a cache hit; data unchanged = 0x00010203.
    -- ----------------------------------------------------------------
    report "Test #2: Read + Valid + Not Dirty + Equal Tag";
    test_num <= 2;
    wait until rising_edge(clk);
    s_read <= '1';
    s_addr <= std_logic_vector(to_unsigned(0, 32));
    wait until falling_edge(s_waitrequest) for 400 ns;
    assert s_waitrequest = '0'
        report "[T2] TIMEOUT: cache never de-asserted waitrequest" severity error;

    assert s_readdata = x"03020100"
        report "[T2] Expected 0x03020100 (cache hit), got 0x" & to_hstring(s_readdata)
        severity error;
    report "[T2] Read 0x" & to_hstring(s_readdata) &
           "  (expected 0x03020100)";

    wait until rising_edge(clk);
    s_read <= '0';
    wait for clk_period;

    -- ----------------------------------------------------------------
    -- Test #3 : Read + Valid + Not Dirty + Not Equal Tag
    --   Address 512 maps to the same cache index as address 0 but has
    --   a different tag.  The cache must evict the clean block and fetch
    --   from memory for addr 512.
    --   Memory bytes 512..515 = 0,1,2,3 (512 mod 256 = 0)
    --   => word = 0x00010203 = 66051  (same numeric value, different block)
    -- ----------------------------------------------------------------
    report "Test #3: Read + Valid + Not Dirty + Not Equal Tag";
    test_num <= 3;
    wait until rising_edge(clk);
    s_read <= '1';
    s_addr <= std_logic_vector(to_unsigned(512, 32));
    wait until falling_edge(s_waitrequest) for 400 ns;
    assert s_waitrequest = '0'
        report "[T3] TIMEOUT: cache never de-asserted waitrequest" severity error;

    assert s_readdata = x"03020100"
        report "[T3] Expected 0x03020100, got 0x" & to_hstring(s_readdata)
        severity error;
    report "[T3] Read 0x" & to_hstring(s_readdata) &
           "  (expected 0x03020100)";

    wait until rising_edge(clk);
    s_read <= '0';
    wait for clk_period;

    -- ----------------------------------------------------------------
    -- Test #4 : Write + Invalid
    --   Address 4 maps to cache index 0 (word 1 of the same block as addr 0).
    --   After Test #3 the cache holds the block for tag=1 (addr 512).
    --   So the block for tag=0 (addr 0-15) is currently evicted (not in cache).
    --   This write hits a block that is now INVALID (we just evicted it in T3).
    --   The cache must fetch the block from memory, then update word 1 to
    --   0xDEADBEEF, marking the block dirty.
    -- ----------------------------------------------------------------
    report "Test #4: Write + Invalid";
    test_num <= 4;
    wait until rising_edge(clk);
    s_write <= '1';
    s_addr  <= std_logic_vector(to_unsigned(4, 32));
    s_writedata <= x"DEADBEEF";
    wait until falling_edge(s_waitrequest) for 400 ns;
    assert s_waitrequest = '0'
        report "[T4] TIMEOUT: write never completed" severity error;

    wait until rising_edge(clk);
    s_write <= '0';
    wait for clk_period;

    -- Verify the write landed: read back address 4
    s_read <= '1';
    s_addr <= std_logic_vector(to_unsigned(4, 32));
    wait until falling_edge(s_waitrequest) for 400 ns;
    assert s_waitrequest = '0'
        report "[T4 verify] TIMEOUT" severity error;
    assert s_readdata = x"DEADBEEF"
        report "[T4 verify] Expected 0xDEADBEEF at addr 4, got 0x" & to_hstring(s_readdata)
        severity error;
    report "[T4 verify] Read back addr 4: 0x" & to_hstring(s_readdata) &
           "  (expected 0xDEADBEEF)";
    wait until rising_edge(clk);
    s_read <= '0';
    wait for clk_period;

    -- ----------------------------------------------------------------
    -- Test #5 : Write + Valid + Not Dirty + Equal Tag
    --   NOTE: After T4 the block IS dirty (we just wrote to it), so this
    --   test actually exercises Write + Valid + Dirty + Equal Tag.
    --   To get a clean block first we'd need a read-only sequence.
    --   We keep the original test structure but correct the assertion:
    --   writing 0xBEEFDEAD to addr 4, block already dirty, same tag.
    --   => should update word 1 in-place, stay dirty.
    -- ----------------------------------------------------------------
    report "Test #5: Write + Valid + Dirty + Equal Tag  (block was left dirty by T4)";
    test_num <= 5;
    wait until rising_edge(clk);
    s_write <= '1';
    s_addr  <= std_logic_vector(to_unsigned(4, 32));
    s_writedata <= x"BEEFDEAD";
    wait until falling_edge(s_waitrequest) for 400 ns;
    assert s_waitrequest = '0'
        report "[T5] TIMEOUT: write never completed" severity error;

    wait until rising_edge(clk);
    s_write <= '0';
    wait for clk_period;

    -- Read back to confirm
    s_read <= '1';
    s_addr <= std_logic_vector(to_unsigned(4, 32));
    wait until falling_edge(s_waitrequest) for 400 ns;
    assert s_readdata = x"BEEFDEAD"
        report "[T5 verify] Expected 0xBEEFDEAD, got 0x" & to_hstring(s_readdata)
        severity error;
    report "[T5 verify] Read back addr 4: 0x" & to_hstring(s_readdata) &
           "  (expected 0xBEEFDEAD)";
    wait until rising_edge(clk);
    s_read <= '0';
    wait for clk_period;

    -- ----------------------------------------------------------------
    -- Test #6 : Write + Valid + Dirty + Not Equal Tag
    --   Write to addr 0 (tag 0).  Cache currently holds tag 0 block
    --   (from T4) with dirty=1.  Wait -- same tag!  We need a different
    --   index *or* a different tag.  Address 0 is in block index 0, tag 0.
    --   Current cache index 0 holds tag 0 (addr 0-15) dirty.
    --   To get "Not Equal Tag" we need to write to the same index but a
    --   different tag, e.g. addr 512 (index 0, tag 1).
    --   That forces writeback of the dirty block then fetch+write.
    -- ----------------------------------------------------------------
    report "Test #6: Write + Valid + Dirty + Not Equal Tag  (addr 512 vs cached tag 0)";
    test_num <= 6;
    wait until rising_edge(clk);
    s_write <= '1';
    s_addr  <= std_logic_vector(to_unsigned(512, 32));  -- same index, different tag
    s_writedata <= x"8BADF00D";
    wait until falling_edge(s_waitrequest) for 400 ns;
    assert s_waitrequest = '0'
        report "[T6] TIMEOUT: write never completed" severity error;

    wait until rising_edge(clk);
    s_write <= '0';
    wait for clk_period;

    -- Verify: read addr 512 => should return 0x8BADF00D
    s_read <= '1';
    s_addr <= std_logic_vector(to_unsigned(512, 32));
    wait until falling_edge(s_waitrequest) for 400 ns;
    assert s_readdata = x"8BADF00D"
        report "[T6 verify] Expected 0x8BADF00D at addr 512, got 0x" & to_hstring(s_readdata)
        severity error;
    report "[T6 verify] Read back addr 512: 0x" & to_hstring(s_readdata) &
           "  (expected 0x8BADF00D)";
    wait until rising_edge(clk);
    s_read <= '0';
    wait for clk_period;

    -- ----------------------------------------------------------------
    -- Test #7 : Write + Valid + Not Dirty + Equal Tag
    --   Cache index 0 now holds tag 1 (addr 512) with dirty=1 from T6.
    --   We need Valid+NotDirty+EqualTag.  Force that by:
    --     (a) reading addr 0 to evict tag1, write back, load tag0 clean, then
    --     (b) write to addr 0.
    --   Step (a):
    -- ----------------------------------------------------------------
    report "Test #7 setup: read addr 0 to get Valid+NotDirty+EqualTag in cache";
    -- First evict tag1 with a read of addr 0 (tag 0, clean after fetch)
    s_read <= '1';
    s_addr <= std_logic_vector(to_unsigned(0, 32));
    wait until falling_edge(s_waitrequest) for 400 ns;
    assert s_waitrequest = '0'
        report "[T7 setup] TIMEOUT evicting and loading addr 0" severity error;
    -- After T6 wrote 0xBEEFDEAD to addr 4 (word1 of block0), that was
    -- written back to memory in T6 writeback.  Now memory[4] = 0xBEEFDEAD.
    -- addr 0 = word0 of same block => 0x00010203 from memory (unchanged).
    assert s_readdata = x"03020100"
        report "[T7 setup] Expected 0x03020100 at addr 0, got 0x" & to_hstring(s_readdata)
        severity error;
    report "[T7 setup] addr 0 = 0x" & to_hstring(s_readdata) &
           "  (expected 0x03020100; block is now Valid+NotDirty+tag0)";
    wait until rising_edge(clk);
    s_read <= '0';
    wait for clk_period;

    report "Test #7: Write + Valid + Not Dirty + Equal Tag";
    test_num <= 7;
    wait until rising_edge(clk);
    s_write <= '1';
    s_addr  <= std_logic_vector(to_unsigned(0, 32));
    s_writedata <= x"C0FFEEEE";
    wait until falling_edge(s_waitrequest) for 400 ns;
    assert s_waitrequest = '0'
        report "[T7] TIMEOUT: write never completed" severity error;

    wait until rising_edge(clk);
    s_write <= '0';
    wait for clk_period;

    -- Verify
    s_read <= '1';
    s_addr <= std_logic_vector(to_unsigned(0, 32));
    wait until falling_edge(s_waitrequest) for 400 ns;
    assert s_readdata = x"C0FFEEEE"
        report "[T7 verify] Expected 0xC0FFEEEE at addr 0, got 0x" & to_hstring(s_readdata)
        severity error;
    report "[T7 verify] addr 0 = 0x" & to_hstring(s_readdata) &
           "  (expected 0xC0FFEEEE)";
    wait until rising_edge(clk);
    s_read <= '0';
    wait for clk_period;

    -- ----------------------------------------------------------------
    -- Test #8 : Read + Valid + Dirty + Equal Tag
    --   Cache index 0 holds tag 0 (addr 0) with dirty=1 (from T7 write).
    --   Read addr 0 -> cache hit, should return 0xC0FFEEEE.
    -- ----------------------------------------------------------------
    report "Test #8: Read + Valid + Dirty + Equal Tag";
    test_num <= 8;
    wait until rising_edge(clk);
    s_read <= '1';
    s_addr <= std_logic_vector(to_unsigned(0, 32));
    wait until falling_edge(s_waitrequest) for 400 ns;
    assert s_waitrequest = '0'
        report "[T8] TIMEOUT: read never completed" severity error;

    assert s_readdata = x"C0FFEEEE"
        report "[T8] Expected 0xC0FFEEEE (dirty hit), got 0x" & to_hstring(s_readdata)
        severity error;
    report "[T8] Read 0x" & to_hstring(s_readdata) &
           "  (expected 0xC0FFEEEE)";

    wait until rising_edge(clk);
    s_read <= '0';
    wait for clk_period;

    -- ----------------------------------------------------------------
    -- Test #9 : Read + Valid + Dirty + Not Equal Tag
    --   Cache index 0 is dirty with tag 0.  Read addr 512 (same index,
    --   tag 1) forces writeback then fetch.
    --   After writeback, memory[0] = 0xC0FFEEEE.
    --   Memory for addr 512: bytes 512..515 = 0,1,2,3 => 0x00010203.
    -- ----------------------------------------------------------------
    report "Test #9: Read + Valid + Dirty + Not Equal Tag";
    test_num <= 9;
    wait until rising_edge(clk);
    s_read <= '1';
    s_addr <= std_logic_vector(to_unsigned(512, 32));
    wait until falling_edge(s_waitrequest) for 400 ns;
    assert s_waitrequest = '0'
        report "[T9] TIMEOUT: read never completed" severity error;

    -- Memory[512..515] = 0,1,2,3 (mod 256 pattern, 512 mod 256 = 0), little-endian => 0x03020100
    assert s_readdata = x"8BADF00D"
        report "[T9] Expected 0x8BADF00D, got 0x" & to_hstring(s_readdata)
        severity error;
    report "[T9] Read 0x" & to_hstring(s_readdata) &
        "  (expected 0x8BADF00D -- T6 wrote this to memory[512])";

    wait until rising_edge(clk);
    s_read <= '0';
    wait for clk_period;

    -- Also verify the dirty-writeback actually landed in memory by reading addr 0
    -- (which should now reflect 0xC0FFEEEE written back from T7).
    -- addr 0 is now in a *different* cache block (after T9 loaded tag1),
    -- so reading addr 0 will trigger another miss and fetch from memory.
    report "Test #9 writeback verify: read addr 0 (expect 0xC0FFEEEE written back)";
    s_read <= '1';
    s_addr <= std_logic_vector(to_unsigned(0, 32));
    wait until falling_edge(s_waitrequest) for 400 ns;
    assert s_waitrequest = '0'
        report "[T9 wb verify] TIMEOUT" severity error;
    -- After T7 wrote 0xC0FFEEEE to addr 0 and T9 evicted it, memory[0] should hold 0xC0FFEEEE.
    -- (This will fail until the write bug is fixed, since nothing was actually written to the cache.)
    assert s_readdata = x"C0FFEEEE"
        report "[T9 wb verify] Writeback not seen: expected 0xC0FFEEEE at addr 0, got 0x" & to_hstring(s_readdata)
        severity error;
    report "[T9 wb verify] addr 0 = 0x" & to_hstring(s_readdata) &
           "  (expected 0xC0FFEEEE confirming writeback)";
    wait until rising_edge(clk);
    s_read <= '0';
    wait for clk_period;

    -- ----------------------------------------------------------------
    -- Test #10 setup : create a dirty block at addr 516 (index 0, tag 1)
    -- ----------------------------------------------------------------
    report "Test #10 set-up: write to addr 516 to create dirty block at tag 1";
    test_num <= 10;
    wait until rising_edge(clk);
    s_write <= '1';
    s_addr  <= std_logic_vector(to_unsigned(516, 32));
    s_writedata <= x"ABADBABE";
    wait until falling_edge(s_waitrequest) for 400 ns;
    assert s_waitrequest = '0'
        report "[T10 setup] TIMEOUT" severity error;

    wait until rising_edge(clk);
    s_write <= '0';
    wait for clk_period;

    -- ----------------------------------------------------------------
    -- Test #10 : Write + Valid + Dirty + Not Equal Tag
    --   Cache index 0 is dirty with tag 1 (addr 512).
    --   Write to addr 4 (same index, tag 0) forces writeback of dirty tag1,
    --   then fetch of tag0 block from memory, then update word 1 to 0xFEEDFACE.
    -- ----------------------------------------------------------------
    report "Test #10: Write + Valid + Dirty + Not Equal Tag";
    test_num <= 11;
    wait until rising_edge(clk);
    s_write <= '1';
    s_addr  <= std_logic_vector(to_unsigned(4, 32));
    s_writedata <= x"FEEDFACE";
    wait until falling_edge(s_waitrequest) for 400 ns;
    assert s_waitrequest = '0'
        report "[T10] TIMEOUT: write never completed" severity error;

    wait until rising_edge(clk);
    s_write <= '0';
    wait for clk_period;

    -- Verify write landed
    s_read <= '1';
    s_addr <= std_logic_vector(to_unsigned(4, 32));
    wait until falling_edge(s_waitrequest) for 400 ns;
    assert s_readdata = x"FEEDFACE"
        report "[T10 verify] Expected 0xFEEDFACE at addr 4, got 0x" & to_hstring(s_readdata)
        severity error;
    report "[T10 verify] addr 4 = 0x" & to_hstring(s_readdata) &
           "  (expected 0xFEEDFACE)";
    wait until rising_edge(clk);
    s_read <= '0';
    wait for clk_period;

    -- Verify T10 writeback: memory[516] should now hold 0xABADBABE
    report "Test #10 writeback verify: read addr 516 (expect 0xABADBABE written back)";
    s_read <= '1';
    s_addr <= std_logic_vector(to_unsigned(516, 32));
    wait until falling_edge(s_waitrequest) for 400 ns;
    assert s_waitrequest = '0'
        report "[T10 wb verify] TIMEOUT" severity error;
    assert s_readdata = x"ABADBABE"
        report "[T10 wb verify] Writeback not seen: expected 0xABADBABE at addr 516, got 0x" & to_hstring(s_readdata)
        severity error;
    report "[T10 wb verify] addr 516 = 0x" & to_hstring(s_readdata) &
           "  (expected 0xABADBABE confirming writeback)";
    wait until rising_edge(clk);
    s_read <= '0';
    wait for clk_period;

    -- ----------------------------------------------------------------
    report "Testbench complete";
    std.env.stop;
    wait;

end process;
    
end;