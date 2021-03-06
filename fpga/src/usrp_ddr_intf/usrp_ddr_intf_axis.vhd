-------------------------------------------------------------------------------
--  Copyright 2013-2014 Jonathon Pendlum
--
--  This is free software: you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation, either version 3 of the License, or
--  (at your option) any later version.
--
--  This is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
--
--  File: usrp_ddr_intf_axis.vhd
--  Author: Jonathon Pendlum (jon.pendlum@gmail.com)
--  Description: Wraps AXI Stream interfaces around usrp_ddr_intf.vhd
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity usrp_ddr_intf_axis is
  generic (
    DDR_CLOCK_FREQ              : integer := 100e6;       -- Clock rate of DDR interface
    BAUD                        : integer := 1e6);        -- UART baud rate
  port (
    -- USRP Interface
    UART_TX                     : out   std_logic;                      -- UART
    RX_DATA_CLK_N               : in    std_logic;                      -- Receive data clock (N)
    RX_DATA_CLK_P               : in    std_logic;                      -- Receive data clock (P)
    RX_DATA_N                   : in    std_logic_vector(4 downto 0);   -- Receive data (N)
    RX_DATA_P                   : in    std_logic_vector(4 downto 0);   -- Receive data (P)
    RX_DATA_STB_N               : in    std_logic;                      -- Receive data strobe (N)
    RX_DATA_STB_P               : in    std_logic;                      -- Receive data strobe (P)
    TX_DATA_N                   : out   std_logic_vector(5 downto 0);   -- Transmit data (N)
    TX_DATA_P                   : out   std_logic_vector(5 downto 0);   -- Transmit data (P)
    TX_DATA_STB_N               : out   std_logic;                      -- Transmit data strobe (N)
    TX_DATA_STB_P               : out   std_logic;                      -- Transmit data strobe (P)
    -- Clock and Reset
    clk                         : in    std_logic;
    rst_n                       : in    std_logic;
    -- Control and Status Registers
    status_addr                 : in    std_logic_vector(7 downto 0);
    status_data                 : out   std_logic_vector(31 downto 0);
    status_stb                  : in    std_logic;
    ctrl_addr                   : in    std_logic_vector(7 downto 0);
    ctrl_data                   : in    std_logic_vector(31 downto 0);
    ctrl_stb                    : in    std_logic;
    -- AXIS Stream Slave Interface (DAC / TX Data)
    axis_slave_tvalid           : in    std_logic;
    axis_slave_tready           : out   std_logic;
    axis_slave_tdata            : in    std_logic_vector(63 downto 0);
    axis_slave_tid              : in    std_logic_vector(2 downto 0);
    axis_slave_tlast            : in    std_logic;
    axis_slave_irq              : out   std_logic;    -- Not used
    -- AXIS Stream Master Interface (ADC / RX Data)
    axis_master_tvalid          : out   std_logic;
    axis_master_tready          : in    std_logic;
    axis_master_tdata           : out   std_logic_vector(63 downto 0);
    axis_master_tdest           : out   std_logic_vector(2 downto 0);
    axis_master_tlast           : out   std_logic;
    axis_master_irq             : out   std_logic;    -- Not used
    -- Sideband signals
    rx_enable_aux               : in    std_logic;
    tx_enable_aux               : in    std_logic);
end entity;

architecture RTL of usrp_ddr_intf_axis is

  -------------------------------------------------------------------------------
  -- Component Declaration
  -------------------------------------------------------------------------------
  component usrp_ddr_intf is
    generic (
      DDR_CLOCK_FREQ          : integer := 100e6;       -- Clock rate of DDR interface
      BAUD                    : integer := 115200);     -- UART baud rate
    port (
      reset                   : in    std_logic;                      -- Asynchronous reset
      -- Control registers (internally synchronized to clk_rx clock domain)
      usrp_mode_ctrl          : in    std_logic_vector(7 downto 0);   -- USRP Mode
      usrp_mode_ctrl_en       : in    std_logic;                      -- USRP Mode data valid, hold until acknowledge
      usrp_mode_ctrl_ack      : out   std_logic;                      -- USRP Mode register acknowledge
      rx_enable               : in    std_logic;                      -- Enable RX processing chain (clears resets)
      rx_gain                 : in    std_logic_vector(31 downto 0);  -- Scales decimating CIC filter output
      rx_cic_decim            : in    std_logic_vector(10 downto 0);  -- Receive CIC decimation rate
      rx_cic_decim_en         : in    std_logic;                      -- Set receive CIC decimation rate
      rx_cic_decim_ack        : out   std_logic;                      -- Set receive CIC decimation rate acknowledge
      rx_fix2float_bypass     : in    std_logic;                      -- Bypass RX fixed to floating point conversion
      rx_cic_bypass           : in    std_logic;                      -- Bypass RX CIC filter
      rx_hb_bypass            : in    std_logic;                      -- Bypass RX half band filter
      tx_enable               : in    std_logic;                      -- Enable TX processing chain (clears resets)
      tx_gain                 : in    std_logic_vector(31 downto 0);  -- Scales interpolating CIC filter output
      tx_cic_interp           : in    std_logic_vector(10 downto 0);  -- Transmit CIC interpolation rate
      tx_cic_interp_en        : in    std_logic;                      -- Set transmit CIC interpolation rate
      tx_cic_interp_ack       : out   std_logic;                      -- Set transmit CIC interpolation rate acknowledge
      tx_float2fix_bypass     : in    std_logic;                      -- Bypass TX floating to fixed point conversion
      tx_cic_bypass           : in    std_logic;                      -- Bypass TX CIC filter
      tx_hb_bypass            : in    std_logic;                      -- Bypass TX half band filter
      -- UART output signals
      uart_busy               : out   std_logic;                      -- UART busy
      UART_TX                 : out   std_logic;                      -- UART
      -- Physical Transmit / Receive data interface
      RX_DATA_CLK_N           : in    std_logic;                      -- Receive data clock (N)
      RX_DATA_CLK_P           : in    std_logic;                      -- Receive data clock (P)
      RX_DATA_N               : in    std_logic_vector(4 downto 0);   -- Receive data (N)
      RX_DATA_P               : in    std_logic_vector(4 downto 0);   -- Receive data (P)
      RX_DATA_STB_N           : in    std_logic;                      -- Receive data strobe (N)
      RX_DATA_STB_P           : in    std_logic;                      -- Receive data strobe (P)
      TX_DATA_N               : out   std_logic_vector(5 downto 0);   -- Transmit data (N)
      TX_DATA_P               : out   std_logic_vector(5 downto 0);   -- Transmit data (P)
      TX_DATA_STB_N           : out   std_logic;                      -- Transmit data strobe (N)
      TX_DATA_STB_P           : out   std_logic;                      -- Transmit data strobe (P)
      clk_rx_locked           : out   std_logic;                      -- RX data MMCM clock locked
      clk_rx_phase            : out   std_logic_vector(9 downto 0);   -- RX data MMCM phase offset, 0 - 559
      rx_phase_init           : in    std_logic_vector(9 downto 0);   -- RX data MMCM phase offset initialization, 0 - 559
      rx_phase_incdec         : in    std_logic;                      -- '1' = Increment, '0' = Decrement
      rx_phase_en             : in    std_logic;                      -- Increment / decrements RX data MMCM phase (Rising edge)
      rx_phase_busy           : out   std_logic;                      -- RX data MMCM phase adjustment in process
      rx_restart_cal          : in    std_logic;                      -- Restart RX data MMCM phase calibration
      rx_cal_complete         : out   std_logic;                      -- RX data MMCM phase calibration complete
      clk_tx_locked           : out   std_logic;                      -- TX data MMCM clock locked
      clk_tx_phase            : out   std_logic_vector(9 downto 0);   -- TX data MMCM phase offset, 0 - 559
      tx_phase_init           : in    std_logic_vector(9 downto 0);   -- TX data MMCM phase offset initialization, 0 - 559
      tx_phase_incdec         : in    std_logic;                      -- '1' = Increment, '0' = Decrement
      tx_phase_en             : in    std_logic;                      -- Increment / decrements TX data MMCM phase (Rising edge)
      tx_phase_busy           : out   std_logic;                      -- TX data MMCM phase adjustment in process
      tx_restart_cal          : in    std_logic;                      -- Restart TX data MMCM phase calibration
      tx_cal_complete         : out   std_logic;                      -- TX data MMCM phase calibration complete
      -- Receive data FIFO interface (all signals on clk_rx_fifo clock domain)
      clk_rx_fifo             : in    std_logic;                      -- Receive data FIFO clock
      rx_fifo_reset           : in    std_logic;                      -- Receive data FIFO reset
      rx_fifo_data_i          : out   std_logic_vector(31 downto 0);  -- Receive data FIFO output
      rx_fifo_data_q          : out   std_logic_vector(31 downto 0);  -- Receive data FIFO output
      rx_fifo_rd_en           : in    std_logic;                      -- Receive data FIFO read enable
      rx_fifo_underflow       : out   std_logic;                      -- Receive data FIFO underflow
      rx_fifo_empty           : out   std_logic;                      -- Receive data FIFO empty
      rx_fifo_almost_empty    : out   std_logic;                      -- Receive data FIFO almost empty
      rx_fifo_overflow_latch  : out   std_logic;                      -- Receive data FIFO overflow (clears on reset)
      rx_fifo_overflow_clr    : in    std_logic;                      -- Receive data FIFO clears overflow latch
      -- Receive data FIFO interface (all signals on clk_tx_fifo clock domain)
      clk_tx_fifo             : in    std_logic;                      -- Transmit data FIFO clock
      tx_fifo_reset           : in    std_logic;                      -- Transmit data FIFO reset
      tx_fifo_data_i          : in    std_logic_vector(31 downto 0);  -- Transmit data FIFO output
      tx_fifo_data_q          : in    std_logic_vector(31 downto 0);  -- Transmit data FIFO output
      tx_fifo_wr_en           : in    std_logic;                      -- Transmit data FIFO write enable
      tx_fifo_overflow        : out   std_logic;                      -- Transmit data FIFO overflow
      tx_fifo_full            : out   std_logic;                      -- Transmit data FIFO full
      tx_fifo_almost_full     : out   std_logic;                      -- Transmit data FIFO almost full
      tx_fifo_underflow_latch : out   std_logic;                      -- Transmit data FIFO underflow (clears on reset)
      tx_fifo_underflow_clr   : in    std_logic);                     -- Transmit data FIFO clears underflow latch
  end component;

  component synchronizer is
    generic (
      STROBE_EDGE               : string    := "N";  -- "R"ising, "F"alling, "B"oth, or "N"one.
      RESET_OUTPUT              : std_logic := '0');
    port (
      clk                       : in    std_logic;
      reset                     : in    std_logic;
      async                     : in    std_logic;      -- Asynchronous input
      sync                      : out   std_logic);     -- Synchronized output
  end component;

  component synchronizer_slv is
    generic (
      STROBE_EDGE               : string           := "N";  -- "R"ising, "F"alling, "B"oth, or "N"one.
      RESET_OUTPUT              : std_logic_vector := "0");
    port (
      clk                       : in    std_logic;
      reset                     : in    std_logic;
      async                     : in    std_logic_vector;      -- Asynchronous input
      sync                      : out   std_logic_vector);     -- Synchronized output
  end component;

  -----------------------------------------------------------------------------
  -- Constants Declaration
  -----------------------------------------------------------------------------
  constant REG_USRP_MODE                : std_logic_vector(31 downto 0) := x"00000001";
  constant REG_RX_PKT_SIZE              : std_logic_vector(31 downto 0) := x"00000002";
  constant REG_RX_DECIM                 : std_logic_vector(31 downto 0) := x"00000003";
  constant REG_RX_GAIN                  : std_logic_vector(31 downto 0) := x"00000004";
  constant REG_TXRX_RESET               : std_logic_vector(31 downto 0) := x"00000005";
  constant REG_TX_INTERP                : std_logic_vector(31 downto 0) := x"00000006";
  constant REG_TX_GAIN                  : std_logic_vector(31 downto 0) := x"00000007";
  constant REG_TXRX_MMCM_PHASE_INIT     : std_logic_vector(31 downto 0) := x"00000008";
  constant REG_TXRX_MMCM_PHASE_ADJ      : std_logic_vector(31 downto 0) := x"00000009";
  constant REG_MISC                     : std_logic_vector(31 downto 0) := x"0000000A";

  -------------------------------------------------------------------------------
  -- Signal Declaration
  -------------------------------------------------------------------------------
  type slv_32x256 is array(0 to 255) of std_logic_vector(31 downto 0);

  signal ctrl_reg                       : slv_32x256 := (others=>(others=>'0'));
  signal status_reg                     : slv_32x256 := (others=>(others=>'0'));
  signal axis_master_tdest_hold         : std_logic_vector(2 downto 0);
  signal axis_master_tdest_safe         : std_logic_vector(2 downto 0);

  signal rst                            : std_logic;

  signal usrp_mode_ctrl                 : std_logic_vector(7 downto 0);
  signal usrp_mode_ctrl_en              : std_logic;
  signal usrp_mode_ctrl_ack             : std_logic;
  signal rx_enable                      : std_logic;
  signal rx_gain                        : std_logic_vector(31 downto 0);
  signal rx_cic_decim                   : std_logic_vector(10 downto 0);
  signal rx_cic_decim_en                : std_logic;
  signal rx_cic_decim_ack               : std_logic;
  signal rx_fix2float_bypass            : std_logic;
  signal rx_cic_bypass                  : std_logic;
  signal rx_hb_bypass                   : std_logic;
  signal tx_enable                      : std_logic;
  signal tx_gain                        : std_logic_vector(31 downto 0);
  signal tx_cic_interp                  : std_logic_vector(10 downto 0);
  signal tx_cic_interp_en               : std_logic;
  signal tx_cic_interp_ack              : std_logic;
  signal tx_float2fix_bypass            : std_logic;
  signal tx_cic_bypass                  : std_logic;
  signal tx_hb_bypass                   : std_logic;
  signal uart_busy                      : std_logic;
  signal clk_rx_locked                  : std_logic;
  signal clk_rx_phase                   : std_logic_vector(9 downto 0);
  signal rx_phase_init                  : std_logic_vector(9 downto 0);
  signal rx_phase_incdec                : std_logic;
  signal rx_phase_en                    : std_logic;
  signal rx_phase_busy                  : std_logic;
  signal rx_restart_cal                 : std_logic;
  signal rx_cal_complete                : std_logic;
  signal clk_tx_locked                  : std_logic;
  signal clk_tx_phase                   : std_logic_vector(9 downto 0);
  signal tx_phase_init                  : std_logic_vector(9 downto 0);
  signal tx_phase_incdec                : std_logic;
  signal tx_phase_en                    : std_logic;
  signal tx_phase_busy                  : std_logic;
  signal tx_restart_cal                 : std_logic;
  signal tx_cal_complete                : std_logic;
  signal clk_rx_fifo                    : std_logic;
  signal rx_fifo_reset                  : std_logic;
  signal rx_fifo_data_i                 : std_logic_vector(31 downto 0);
  signal rx_fifo_data_q                 : std_logic_vector(31 downto 0);
  signal rx_fifo_rd_en                  : std_logic;
  signal rx_fifo_underflow              : std_logic;
  signal rx_fifo_empty                  : std_logic;
  signal rx_fifo_empty_n                : std_logic;
  signal rx_fifo_almost_empty           : std_logic;
  signal rx_fifo_overflow_latch         : std_logic;
  signal rx_fifo_overflow_clr           : std_logic;
  signal clk_tx_fifo                    : std_logic;
  signal tx_fifo_reset                  : std_logic;
  signal tx_fifo_data_i                 : std_logic_vector(31 downto 0);
  signal tx_fifo_data_q                 : std_logic_vector(31 downto 0);
  signal tx_fifo_wr_en                  : std_logic;
  signal tx_fifo_overflow               : std_logic;
  signal tx_fifo_full                   : std_logic;
  signal tx_fifo_almost_full            : std_logic;
  signal tx_fifo_underflow_latch        : std_logic;
  signal tx_fifo_underflow_clr          : std_logic;

  signal clk_ddr_locked                 : std_logic;
  signal cal_complete                   : std_logic;

  signal async                          : std_logic_vector(30 downto 0);
  signal sync                           : std_logic_vector(30 downto 0);
  signal usrp_mode_ctrl_ack_sync        : std_logic;
  signal rx_cic_decim_ack_sync          : std_logic;
  signal tx_cic_interp_ack_sync         : std_logic;
  signal rx_fifo_overflow_latch_sync    : std_logic;
  signal tx_fifo_underflow_latch_sync   : std_logic;
  signal clk_ddr_locked_sync            : std_logic;
  signal clk_rx_phase_sync              : std_logic_vector(9 downto 0);
  signal clk_tx_phase_sync              : std_logic_vector(9 downto 0);
  signal rx_cal_complete_sync           : std_logic;
  signal tx_cal_complete_sync           : std_logic;
  signal rx_phase_busy_sync             : std_logic;
  signal tx_phase_busy_sync             : std_logic;
  signal uart_busy_sync                 : std_logic;

  signal rx_fifo_bypass                 : std_logic;
  signal rx_enable_sideband             : std_logic;
  signal tx_enable_sideband             : std_logic;
  signal rx_enable_aux_reg              : std_logic;
  signal tx_enable_aux_reg              : std_logic;
  signal rx_packet_size                 : std_logic_vector(23 downto 0);
  signal rx_fifo_cnt                    : integer;

begin

  rst                                   <= NOT(rst_n);
  axis_master_irq                       <= '0';
  axis_slave_irq                        <= '0';

  -- Sychronizers to cross clock domains
  inst_synchronizer_slv : synchronizer_slv
    port map (
      clk                               => clk,
      reset                             => rst,
      async                             => async,
      sync                              => sync);

  async(0)                              <= rx_cic_decim_ack;
  async(1)                              <= tx_cic_interp_ack;
  async(2)                              <= usrp_mode_ctrl_ack;
  async(12 downto 3)                    <= clk_rx_phase;
  async(22 downto 13)                   <= clk_tx_phase;
  async(23)                             <= rx_phase_busy;
  async(24)                             <= tx_phase_busy;
  async(25)                             <= uart_busy;
  async(26)                             <= clk_ddr_locked;
  async(27)                             <= rx_cal_complete;
  async(28)                             <= tx_cal_complete;
  rx_cic_decim_ack_sync                 <= sync(0);
  tx_cic_interp_ack_sync                <= sync(1);
  usrp_mode_ctrl_ack_sync               <= sync(2);
  clk_rx_phase_sync                     <= sync(12 downto 3);
  clk_tx_phase_sync                     <= sync(22 downto 13);
  rx_phase_busy_sync                    <= sync(23);
  tx_phase_busy_sync                    <= sync(24);
  uart_busy_sync                        <= sync(25);
  clk_ddr_locked_sync                   <= sync(26);
  rx_cal_complete_sync                  <= sync(27);
  tx_cal_complete_sync                  <= sync(28);

  clk_ddr_locked                        <= clk_rx_locked AND clk_tx_locked;

  -------------------------------------------------------------------------------
  -- Enable and Acknowledge Signals
  -------------------------------------------------------------------------------
  proc_enable_and_ack : process(clk,rst)
  begin
    if (rst = '1') then
      usrp_mode_ctrl_en                 <= '0';
      rx_cic_decim_en                   <= '0';
      tx_cic_interp_en                  <= '0';
    else
      if rising_edge(clk) then
        -- Set the required enables to update the registers.
        -- Deassert enables only after acknowledgement.
        -- Bank 3 is Decimation & Interpolation Rate
        if (ctrl_stb = '1' AND ctrl_addr = x"03") then
          rx_cic_decim_en               <= '1';
        end if;
        if (rx_cic_decim_ack_sync = '1') then
          rx_cic_decim_en               <= '0';
        end if;
        -- Bank 3 is Decimation & Interpolation Rate
        if (ctrl_stb = '1' AND ctrl_addr = x"03") then
          tx_cic_interp_en              <= '1';
        end if;
        if (tx_cic_interp_ack_sync = '1') then
          tx_cic_interp_en              <= '0';
        end if;
        -- Bank 1 is USRP mode
        if (ctrl_stb = '1' AND ctrl_addr = x"01") then
          usrp_mode_ctrl_en             <= '1';
        end if;
        if (usrp_mode_ctrl_ack_sync = '1') then
          usrp_mode_ctrl_en             <= '0';
        end if;
      end if;
    end if;
  end process;

  -------------------------------------------------------------------------------
  -- AXIS Stream to TX Data
  -------------------------------------------------------------------------------
  clk_tx_fifo                                   <= clk;
  tx_fifo_data_q                                <= axis_slave_tdata(63 downto 32);
  tx_fifo_data_i                                <= axis_slave_tdata(31 downto 0);
  tx_fifo_wr_en                                 <= axis_slave_tvalid;
  axis_slave_tready                             <= NOT(tx_fifo_full);

  -------------------------------------------------------------------------------
  -- RX Data to AXIS Stream
  -------------------------------------------------------------------------------
  -- This counter below is used to assert the tlast signal at the end of the transfer.
  proc_gen_axis_stream : process(clk,rst)
  begin
    if (rst = '1') then
      rx_fifo_cnt                               <= 0;
    else
      if rising_edge(clk) then
        if (rx_enable = '0') then
          rx_fifo_cnt                           <= to_integer(unsigned(rx_packet_size));
        else
          -- Decrement only on successful reads from the FIFO
          if (axis_master_tready = '1' AND rx_fifo_empty = '0') then
            rx_fifo_cnt                         <= rx_fifo_cnt - 1;
            if (rx_fifo_cnt = 1) then
              rx_fifo_cnt                       <= to_integer(unsigned(rx_packet_size));
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;

  rx_fifo_rd_en                                 <= (axis_master_tready OR rx_fifo_bypass) AND NOT(rx_fifo_empty) AND rx_enable;
  axis_master_tdata                             <= rx_fifo_data_q & rx_fifo_data_i;
  axis_master_tvalid                            <= (NOT(rx_fifo_empty) AND rx_enable);
  axis_master_tlast                             <= '1' when rx_fifo_cnt = 1 AND rx_enable = '1' else '0';
  axis_master_tdest                             <= axis_master_tdest_safe;

  -------------------------------------------------------------------------------
  -- USRP DDR Interface Instance
  -------------------------------------------------------------------------------
  inst_usrp_ddr_intf : usrp_ddr_intf
    generic map (
      DDR_CLOCK_FREQ                            => DDR_CLOCK_FREQ,
      BAUD                                      => BAUD)
    port map (
      reset                                     => rst,
      usrp_mode_ctrl                            => usrp_mode_ctrl,
      usrp_mode_ctrl_en                         => usrp_mode_ctrl_en,
      usrp_mode_ctrl_ack                        => usrp_mode_ctrl_ack,
      rx_enable                                 => rx_enable,
      rx_gain                                   => rx_gain,
      rx_cic_decim                              => rx_cic_decim,
      rx_cic_decim_en                           => rx_cic_decim_en,
      rx_cic_decim_ack                          => rx_cic_decim_ack,
      rx_fix2float_bypass                       => rx_fix2float_bypass,
      rx_cic_bypass                             => rx_cic_bypass,
      rx_hb_bypass                              => rx_hb_bypass,
      tx_enable                                 => tx_enable,
      tx_gain                                   => tx_gain,
      tx_cic_interp                             => tx_cic_interp,
      tx_cic_interp_en                          => tx_cic_interp_en,
      tx_cic_interp_ack                         => tx_cic_interp_ack,
      tx_float2fix_bypass                       => tx_float2fix_bypass,
      tx_cic_bypass                             => tx_cic_bypass,
      tx_hb_bypass                              => tx_hb_bypass,
      uart_busy                                 => uart_busy,
      UART_TX                                   => UART_TX,
      RX_DATA_CLK_N                             => RX_DATA_CLK_N,
      RX_DATA_CLK_P                             => RX_DATA_CLK_P,
      RX_DATA_N                                 => RX_DATA_N,
      RX_DATA_P                                 => RX_DATA_P,
      RX_DATA_STB_N                             => RX_DATA_STB_N,
      RX_DATA_STB_P                             => RX_DATA_STB_P,
      TX_DATA_N                                 => TX_DATA_N,
      TX_DATA_P                                 => TX_DATA_P,
      TX_DATA_STB_N                             => TX_DATA_STB_N,
      TX_DATA_STB_P                             => TX_DATA_STB_P,
      clk_rx_locked                             => clk_rx_locked,
      clk_rx_phase                              => clk_rx_phase,
      rx_phase_init                             => rx_phase_init,
      rx_phase_incdec                           => rx_phase_incdec,
      rx_phase_en                               => rx_phase_en,
      rx_phase_busy                             => rx_phase_busy,
      rx_restart_cal                            => rx_restart_cal,
      rx_cal_complete                           => rx_cal_complete,
      clk_tx_locked                             => clk_tx_locked,
      clk_tx_phase                              => clk_tx_phase,
      tx_phase_init                             => tx_phase_init,
      tx_phase_incdec                           => tx_phase_incdec,
      tx_phase_en                               => tx_phase_en,
      tx_phase_busy                             => tx_phase_busy,
      tx_restart_cal                            => tx_restart_cal,
      tx_cal_complete                           => tx_cal_complete,
      clk_rx_fifo                               => clk,
      rx_fifo_reset                             => rx_fifo_reset,
      rx_fifo_data_i                            => rx_fifo_data_i,
      rx_fifo_data_q                            => rx_fifo_data_q,
      rx_fifo_rd_en                             => rx_fifo_rd_en,
      rx_fifo_underflow                         => rx_fifo_underflow,
      rx_fifo_empty                             => rx_fifo_empty,
      rx_fifo_almost_empty                      => rx_fifo_almost_empty,
      rx_fifo_overflow_latch                    => rx_fifo_overflow_latch,
      rx_fifo_overflow_clr                      => rx_fifo_overflow_clr,
      clk_tx_fifo                               => clk,
      tx_fifo_reset                             => tx_fifo_reset,
      tx_fifo_data_i                            => tx_fifo_data_i,
      tx_fifo_data_q                            => tx_fifo_data_q,
      tx_fifo_wr_en                             => tx_fifo_wr_en,
      tx_fifo_overflow                          => tx_fifo_overflow,
      tx_fifo_full                              => tx_fifo_full,
      tx_fifo_almost_full                       => tx_fifo_almost_full,
      tx_fifo_underflow_latch                   => tx_fifo_underflow_latch,
      tx_fifo_underflow_clr                     => tx_fifo_underflow_clr);

  -------------------------------------------------------------------------------
  -- Control and status registers.
  -------------------------------------------------------------------------------
  proc_ctrl_status_reg : process(clk,rst)
  begin
    if (rst = '1') then
      ctrl_reg                                  <= (others=>(others=>'0'));
      axis_master_tdest_safe                    <= (others=>'0');
      rx_enable_aux_reg                         <= '0';
      tx_enable_aux_reg                         <= '0';
    else
      if rising_edge(clk) then
        -- Update control registers only when accessed
        if (ctrl_stb = '1') then
          ctrl_reg(to_integer(unsigned(ctrl_addr(7 downto 0)))) <= ctrl_data;
        end if;
        -- Output status register
        if (status_stb = '1') then
          status_data                           <= status_reg(to_integer(unsigned(status_addr(7 downto 0))));
        end if;
        -- The destination can only update when no data is being transmitted, i.e. RX disabled
        if (rx_enable = '0') then
          axis_master_tdest_safe                <= axis_master_tdest_hold;
        end if;
        -- Register sideband signals
        if (rx_enable_sideband = '1') then
          rx_enable_aux_reg                     <= rx_enable_aux;
        else
          rx_enable_aux_reg                     <= '0';
        end if;
        if (tx_enable_sideband = '1') then
          tx_enable_aux_reg                     <= tx_enable_aux;
        else
          tx_enable_aux_reg                     <= '0';
        end if;
      end if;
    end if;
  end process;

  -- Control Registers
  -- Bank 0 (RX & TX Enable, and output destination)
  rx_enable                             <= ctrl_reg(0)(0) OR rx_enable_aux_reg;
  tx_enable                             <= ctrl_reg(0)(1) OR tx_enable_aux_reg;
  rx_enable_sideband                    <= ctrl_reg(0)(2);
  tx_enable_sideband                    <= ctrl_reg(0)(3);
  rx_fifo_reset                         <= ctrl_reg(0)(4);
  tx_fifo_reset                         <= ctrl_reg(0)(5);
  rx_fifo_bypass                        <= ctrl_reg(0)(6);
  rx_fifo_overflow_clr                  <= ctrl_reg(0)(7);
  tx_fifo_underflow_clr                 <= ctrl_reg(0)(8);
  axis_master_tdest_hold                <= ctrl_reg(0)(31 downto 29);
  -- Bank 1 (USRP Mode)
  usrp_mode_ctrl                        <= ctrl_reg(1)(7 downto 0);
  -- Bank 2 (RX & TX Floating Point Bypass, RX Packet Size)
  rx_packet_size                        <= ctrl_reg(2)(23 downto 0);
  rx_fix2float_bypass                   <= ctrl_reg(2)(24);
  rx_cic_bypass                         <= ctrl_reg(2)(25);
  rx_hb_bypass                          <= ctrl_reg(2)(26);
  tx_float2fix_bypass                   <= ctrl_reg(2)(27);
  tx_cic_bypass                         <= ctrl_reg(2)(28);
  tx_hb_bypass                          <= ctrl_reg(2)(29);
  -- Bank 3 (Decimation and Interpolation Rate)
  rx_cic_decim                          <= ctrl_reg(3)(10 downto 0);
  tx_cic_interp                         <= ctrl_reg(3)(26 downto 16);
  -- Bank 4 (RX Gain)
  rx_gain                               <= ctrl_reg(4);
  -- Bank 5 (TX Gain)
  tx_gain                               <= ctrl_reg(5);
  -- Bank 6 (MMCM Phase Setting & Manual Adjustment)
  rx_restart_cal                        <= ctrl_reg(6)(0);
  rx_phase_init                         <= ctrl_reg(6)(10 downto 1);
  tx_restart_cal                        <= ctrl_reg(6)(16);
  tx_phase_init                         <= ctrl_reg(6)(26 downto 17);
  rx_phase_en                           <= ctrl_reg(6)(28);
  rx_phase_incdec                       <= ctrl_reg(6)(29);
  tx_phase_en                           <= ctrl_reg(6)(30);
  tx_phase_incdec                       <= ctrl_reg(6)(31);

  -- Status Registers
  -- Bank 0 (RX & TX Enable, and output destination Readback)
  status_reg(0)(0)                      <= rx_enable;
  status_reg(0)(1)                      <= tx_enable;
  status_reg(0)(2)                      <= rx_enable_sideband;
  status_reg(0)(3)                      <= tx_enable_sideband;
  status_reg(0)(4)                      <= rx_fifo_reset;
  status_reg(0)(5)                      <= tx_fifo_reset;
  status_reg(0)(6)                      <= rx_fifo_bypass;
  status_reg(0)(7)                      <= rx_fifo_overflow_clr;
  status_reg(0)(8)                      <= tx_fifo_underflow_clr;
  status_reg(0)(31 downto 29)           <= axis_master_tdest_safe;
  -- Bank 1 (USRP Mode Readback)
  status_reg(1)(7 downto 0)             <= usrp_mode_ctrl;
  -- Bank 2 (RX & TX Floating Point Bypass, RX Packet Size Readback)
  status_reg(2)(23 downto 0)            <= rx_packet_size;
  status_reg(2)(24)                     <= rx_fix2float_bypass;
  status_reg(2)(25)                     <= rx_cic_bypass;
  status_reg(2)(26)                     <= rx_hb_bypass;
  status_reg(2)(27)                     <= tx_float2fix_bypass;
  status_reg(2)(28)                     <= tx_cic_bypass;
  status_reg(2)(29)                     <= tx_hb_bypass;
  -- Bank 3 (Decimation and Interpolation Rate Readback)
  status_reg(3)(10 downto 0)            <= rx_cic_decim;
  status_reg(3)(26 downto 16)           <= tx_cic_interp;
  -- Bank 4 (RX Gain Readback)
  status_reg(4)                         <= rx_gain;
  -- Bank 5 (TX Gain Readback)
  status_reg(5)                         <= tx_gain;
  -- Bank 6 (MMCM Phase Setting & Manual Adjustment Readback)
  status_reg(6)(0)                      <= rx_restart_cal;
  status_reg(6)(10 downto 1)            <= rx_phase_init;
  status_reg(6)(16)                     <= tx_restart_cal;
  status_reg(6)(26 downto 17)           <= tx_phase_init;
  status_reg(6)(28)                     <= rx_phase_en;
  status_reg(6)(29)                     <= rx_phase_incdec;
  status_reg(6)(30)                     <= tx_phase_en;
  status_reg(6)(31)                     <= tx_phase_incdec;
  -- Bank 7
  status_reg(7)(0)                      <= clk_ddr_locked_sync;
  status_reg(7)(1)                      <= rx_fifo_overflow_latch;
  status_reg(7)(2)                      <= tx_fifo_underflow_latch;
  status_reg(7)(3)                      <= rx_cal_complete_sync;
  status_reg(7)(4)                      <= tx_cal_complete_sync;
  status_reg(7)(5)                      <= rx_phase_busy_sync;
  status_reg(7)(6)                      <= tx_phase_busy_sync;
  status_reg(7)(7)                      <= uart_busy_sync;
  status_reg(7)(19 downto 10)           <= clk_rx_phase_sync;
  status_reg(7)(29 downto 20)           <= clk_tx_phase_sync;

end architecture;