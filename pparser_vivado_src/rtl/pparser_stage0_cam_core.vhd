library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library cam;
use cam.cam_init_file_pack_xst.ALL;

entity pparser_stage0_cam_core is
  port (
    clk        : in  STD_LOGIC;
    rst        : in  STD_LOGIC;
    cmp_din    : in  STD_LOGIC_VECTOR(16 downto 0);
    ready      : out STD_LOGIC;
    match      : out STD_LOGIC;
    match_addr : out STD_LOGIC_VECTOR(3 downto 0)
  );
end pparser_stage0_cam_core;

architecture rtl of pparser_stage0_cam_core is
  type state_t is (INIT_PULSE, INIT_WAIT_BUSY_HI, INIT_WAIT_BUSY_LO, RUN);
  type cam_word_array_t is array (0 to 15) of STD_LOGIC_VECTOR(16 downto 0);

  impure function init_cam_words(filename : in string) return cam_word_array_t is
    variable flat_mem : STD_LOGIC_VECTOR((16 * 17) - 1 downto 0) := (others => '0');
    variable line_count : integer := 16;
    variable words : cam_word_array_t := (others => (others => '0'));
  begin
    read_meminit_file(filename, 16, 17, flat_mem, line_count);
    for i in 0 to 15 loop
      words(i) := flat_mem(((i + 1) * 17) - 1 downto (i * 17));
    end loop;
    return words;
  end function;

  constant CAM_DATA_INIT : cam_word_array_t := init_cam_words("pparser_stage0_cam_data.mif");
  constant CAM_MASK_INIT : cam_word_array_t := init_cam_words("pparser_stage0_cam_mask.mif");

  signal state_r          : state_t := INIT_PULSE;
  signal init_index_r     : unsigned(3 downto 0) := (others => '0');
  signal we_r             : STD_LOGIC := '0';
  signal busy_w           : STD_LOGIC;
  signal match_w          : STD_LOGIC;
  signal match_addr_w     : STD_LOGIC_VECTOR(3 downto 0);
  signal wr_addr_w        : STD_LOGIC_VECTOR(3 downto 0);
  signal din_w            : STD_LOGIC_VECTOR(16 downto 0);
  signal data_mask_w      : STD_LOGIC_VECTOR(16 downto 0);
  signal ready_r          : STD_LOGIC := '0';
begin
  wr_addr_w <= STD_LOGIC_VECTOR(init_index_r);
  din_w <= CAM_DATA_INIT(to_integer(init_index_r));
  data_mask_w <= CAM_MASK_INIT(to_integer(init_index_r));

  stage0_cam_i : entity cam.cam_top
    generic map (
      C_ADDR_TYPE             => 0,
      C_DEPTH                 => 16,
      C_FAMILY                => "virtex6",
      C_HAS_CMP_DIN           => 1,
      C_HAS_EN                => 1,
      C_HAS_MULTIPLE_MATCH    => 0,
      C_HAS_READ_WARNING      => 0,
      C_HAS_SINGLE_MATCH      => 0,
      C_HAS_WE                => 1,
      C_MATCH_RESOLUTION_TYPE => 0,
      C_MEM_INIT              => 0,
      C_MEM_INIT_FILE         => "",
      C_MEM_TYPE              => 0,
      C_REG_OUTPUTS           => 0,
      C_TERNARY_MODE          => 1,
      C_WIDTH                 => 17
    )
    port map (
      CLK            => clk,
      CMP_DATA_MASK  => (others => '0'),
      CMP_DIN        => cmp_din,
      DATA_MASK      => data_mask_w,
      DIN            => din_w,
      EN             => '1',
      WE             => we_r,
      WR_ADDR        => wr_addr_w,
      BUSY           => busy_w,
      MATCH          => match_w,
      MATCH_ADDR     => match_addr_w,
      MULTIPLE_MATCH => open,
      READ_WARNING   => open,
      SINGLE_MATCH   => open
    );

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state_r <= INIT_PULSE;
        init_index_r <= (others => '0');
        we_r <= '0';
        ready_r <= '0';
      else
        case state_r is
          when INIT_PULSE =>
            we_r <= '1';
            ready_r <= '0';
            state_r <= INIT_WAIT_BUSY_HI;
          when INIT_WAIT_BUSY_HI =>
            we_r <= '0';
            if busy_w = '1' then
              state_r <= INIT_WAIT_BUSY_LO;
            end if;
          when INIT_WAIT_BUSY_LO =>
            if busy_w = '0' then
              if init_index_r = 3 then
                state_r <= RUN;
                ready_r <= '1';
              else
                init_index_r <= init_index_r + 1;
                state_r <= INIT_PULSE;
              end if;
            end if;
          when RUN =>
            we_r <= '0';
            ready_r <= '1';
        end case;
      end if;
    end if;
  end process;

  ready <= ready_r;
  match <= match_w;
  match_addr <= match_addr_w;
end rtl;
