// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Alessandro Ottaviano <aottaviano@iis.ee.ethz.ch>
// Victor Isachi <victor.isachi@unibo.it>

module astral_fixture;

  `include "cheshire/typedef.svh"
  `include "register_interface/assign.svh"
  `include "axi/assign.svh"

  import carfield_chip_pkg::*;
  import cheshire_pkg::*;
  import carfield_pkg::*;
`ifdef SAFED_ENABLE
  import safety_island_pkg::*;
`endif
  import astral_padframe_periph_config_reg_pkg::*;
  import pkg_internal_astral_padframe_periph::*;

  ///////////
  //  DPI  //
  ///////////

  import "DPI-C" function byte read_elf(input string filename);
  import "DPI-C" function byte get_entry(output longint entry);
  import "DPI-C" function byte get_section(output longint address, output longint len);
  import "DPI-C" context function byte read_section(input longint address, inout byte buffer[], input longint len);

  /////////
  // DUT //
  /////////

  localparam time         ClkPeriodRef  = 1us;  // 1MHz reference clock
  localparam time         ClkPeriodExt  = 7.14ns; // 140MHz: the maximum frequency supported by the pads according to doc
  localparam time         ClkPeriodJtag = 100ns; // 10MHz JTAG clock
  localparam int unsigned RstCycles     = 5;
  localparam int unsigned RstCyclesVip  = 5;
  localparam real         TAppl         = 0.1;
  localparam real         TTest         = 0.9;

  localparam int NumPhys  = 2;
  localparam int NumChips = 2;

  ////////////////////////
  // IN/OUT declaration //
  ////////////////////////

  logic       ref_clk, ext_clk;
  logic       bypass_pll;
  logic       pwr_on_rst_n;
  logic       pwr_on_ext_rst_n;
  logic       secure_boot;
  logic       testmode_hostd;
  logic [1:0] bootmode_hostd;
  logic [1:0] bootmode_safed;
  logic [1:0] bootmode_secd;

  logic jtag_hostd_tck;
  logic jtag_hostd_trst_n;
  logic jtag_hostd_tms;
  logic jtag_hostd_tdi;
  logic jtag_hostd_tdo;

  logic jtag_safed_tck;
  logic jtag_safed_trst_n;
  logic jtag_safed_tms;
  logic jtag_safed_tdi;
  logic jtag_safed_tdo;

  logic jtag_secd_tck;
  logic jtag_secd_trst_n;
  logic jtag_secd_tms;
  logic jtag_secd_tdi;
  logic jtag_secd_tdo;

  logic jtag_pll_tck;
  logic jtag_pll_trst_n;
  logic jtag_pll_tms;
  logic jtag_pll_tdi;
  logic jtag_pll_tdo;

  logic uart_hostd_tx;
  logic uart_hostd_rx;
  logic uart_secd_tx;
  logic uart_secd_rx;

  // Serial Link signals
  logic [SlinkNumChan-1:0]                    slink_hostd_rcv_clk_to_vip;
  logic [SlinkNumChan-1:0]                    slink_hostd_rcv_clk_from_vip;
  logic [SlinkNumChan-1:0][SlinkNumLanes-1:0] slink_hostd_to_vip;
  logic [SlinkNumChan-1:0][SlinkNumLanes-1:0] slink_hostd_from_vip;

  ///////////////////////
  // INOUT declaration //
  ///////////////////////

  // Clock
  wire                                w_ref_clk;
  // Bypass PLL
  wire                                w_bypass_pll;
  // External clock
  wire                                w_ext_clk;
  // POR (power-on reset, active low)
  wire                                w_pwr_on_rst_n;
  // secure boot emulation
  wire                                w_secure_boot;
  // Bootmode (hostd)
  wire [2:0]                          w_bootmode_hostd;
  // Bootmode (safed)
  wire [1:0]                          w_bootmode_safed;
  // Bootmode (secd)
  wire [1:0]                          w_bootmode_secd;
  // JTAG (hostd)
  wire                                w_jtag_hostd_tck;
  wire                                w_jtag_hostd_tms;
  wire                                w_jtag_hostd_tdi;
  wire                                w_jtag_hostd_trstn;
  wire                                w_jtag_hostd_tdo;
  // JTAG (safed)
  wire                                w_jtag_safed_tck;
  wire                                w_jtag_safed_tms;
  wire                                w_jtag_safed_tdi;
  wire                                w_jtag_safed_trstn;
  wire                                w_jtag_safed_tdo;
  // JTAG (secd)
  wire                                w_jtag_secd_tck;
  wire                                w_jtag_secd_tms;
  wire                                w_jtag_secd_tdi;
  wire                                w_jtag_secd_trstn;
  wire                                w_jtag_secd_tdo;
  // GPIOs
  wire [21:0]                         w_gpio;
  // Serial Link
  wire                                w_slink_hostd_rcv_clk_to_vip;
  wire                                w_slink_hostd_rcv_clk_from_vip;
  wire [SlinkNumLanes-1:0]            w_slink_hostd_to_vip;
  wire [SlinkNumLanes-1:0]            w_slink_hostd_from_vip;
  // hyperbus tristate signals
  wire [NumPhys-1:0][NumChips-1:0]    w_hyper_csn;
  wire [NumPhys-1:0]                  w_hyper_ck;
  wire [NumPhys-1:0]                  w_hyper_ckn;
  wire [NumPhys-1:0]                  w_hyper_rwds;
  wire [NumPhys-1:0][7:0]             w_hyper_dq;
  wire [NumPhys-1:0]                  w_hyper_resetn;
  // SPI (hostd)
  wire                                w_spi_hostd_sck;
  wire [SpihNumCs-1:0]                w_spi_hostd_csb;
  wire [3:0]                          w_spi_hostd_sd;
  // SPI (secd)
  wire                                w_spi_secd_sck;
  wire [SpihNumCs-1:0]                w_spi_secd_csb;
  wire [3:0]                          w_spi_secd_sd;
  // UART (hostd)
  wire                                w_uart_hostd_tx;
  wire                                w_uart_hostd_rx;
  // UART (secd)
  wire                                w_uart_secd_tx;
  wire                                w_uart_secd_rx;
  // I2C (hostd)
  wire                                w_i2c_hostd_sda_i;
  wire                                w_i2c_hostd_sda_o;
  wire                                w_i2c_hostd_sda_en;
  wire                                w_i2c_hostd_scl_i;
  wire                                w_i2c_hostd_scl_o;
  wire                                w_i2c_hostd_scl_en;
  // CAN
  wire                                w_can_tx;
  wire                                w_can_rx;
  // Ethernet
  wire                                w_eth_rst;
  wire                                w_eth_txck;
  wire                                w_eth_txctl;
  wire                                w_eth_txd0;
  wire                                w_eth_txd1;
  wire                                w_eth_txd2;
  wire                                w_eth_txd3;
  wire                                w_eth_mdc;
  wire                                w_eth_md;
  wire                                w_eth_rxck;
  wire                                w_eth_rxctl;
  wire                                w_eth_rxd0;
  wire                                w_eth_rxd1;
  wire                                w_eth_rxd2;
  wire                                w_eth_rxd3;
  // Debug signals
  wire [2:0]                          debug_signals;

  wire                                w_jtag_pll_tck;
  wire                                w_jtag_pll_tms;
  wire                                w_jtag_pll_tdi;
  wire                                w_jtag_pll_trstn;
  wire                                w_jtag_pll_tdo;
  // Muxed pads
  wire                                w_muxed_v_00;
  wire                                w_muxed_v_01;
  wire                                w_muxed_v_02;
  wire                                w_muxed_v_03;
  wire                                w_muxed_v_04;
  wire                                w_muxed_v_05;
  wire                                w_muxed_v_06;
  wire                                w_muxed_v_07;
  wire                                w_muxed_v_08;
  wire                                w_muxed_v_09;
  wire                                w_muxed_v_10;
  wire                                w_muxed_v_11;
  wire                                w_muxed_v_12;
  wire                                w_muxed_v_13;
  wire                                w_muxed_v_14;
  wire                                w_muxed_v_15;
  wire                                w_muxed_v_16;
  wire                                w_muxed_v_17;
  wire                                w_muxed_v_18;
  wire                                w_muxed_v_19;
  wire                                w_muxed_v_20;
  wire                                w_muxed_v_21;
  // Muxed alternate functions
  logic                               mux_0_spih_sck;
  logic                               mux_0_spih_csb_0;
  logic                               mux_0_spih_csb_1;
  logic                               mux_0_spih_sd_0;
  logic                               mux_0_spih_sd_1;
  logic                               mux_0_spih_sd_2;
  logic                               mux_0_spih_sd_3;
  logic                               mux_0_eth_rxck;
  logic                               mux_0_eth_rxctl;
  logic                               mux_0_eth_rxd_0;
  logic                               mux_0_eth_rxd_1;
  logic                               mux_0_eth_rxd_2;
  logic                               mux_0_eth_rxd_3;
  logic                               mux_0_eth_txck;
  logic                               mux_0_eth_txctl;
  logic                               mux_0_eth_txd_0;
  logic                               mux_0_eth_txd_1;
  logic                               mux_0_eth_txd_2;
  logic                               mux_0_eth_txd_3;
  logic                               mux_0_eth_md;
  logic                               mux_0_eth_mdc;
  logic                               mux_0_eth_rst_n;
  logic                               mux_1_can_rx;
  logic                               mux_1_can_tx;
  logic                               mux_1_slink_rcv_clk_i;
  logic                               mux_1_slink_0_i;
  logic                               mux_1_slink_1_i;
  logic                               mux_1_slink_2_i;
  logic                               mux_1_slink_3_i;
  logic                               mux_1_slink_4_i;
  logic                               mux_1_slink_5_i;
  logic                               mux_1_slink_6_i;
  logic                               mux_1_slink_7_i;
  logic                               mux_1_slink_rcv_clk_o;
  logic                               mux_1_slink_0_o;
  logic                               mux_1_slink_1_o;
  logic                               mux_1_slink_2_o;
  logic                               mux_1_slink_3_o;
  logic                               mux_1_slink_4_o;
  logic                               mux_1_slink_5_o;
  logic                               mux_1_slink_6_o;
  logic                               mux_1_slink_7_o;
  logic                               mux_2_i2c_sda_o;
  logic                               mux_2_i2c_sda_i;
  logic                               mux_2_i2c_sda_en;
  logic                               mux_2_i2c_scl_o;
  logic                               mux_2_i2c_scl_i;
  logic                               mux_2_i2c_scl_en;
  logic                               mux_3_spih_ot_sck;
  logic                               mux_3_spih_ot_csb;
  logic                               mux_3_spih_ot_sd_0;
  logic                               mux_3_spih_ot_sd_1;
  logic                               mux_3_spih_ot_sd_2;
  logic                               mux_3_spih_ot_sd_3;
  logic                               mux_4_gpio_0;
  logic                               mux_4_gpio_1;
  logic                               mux_4_gpio_2;
  logic                               mux_4_gpio_3;
  logic                               mux_4_gpio_4;
  logic                               mux_4_gpio_5;
  logic                               mux_4_gpio_6;
  logic                               mux_4_gpio_7;
  logic                               mux_4_gpio_8;
  logic                               mux_4_gpio_9;
  logic                               mux_4_gpio_10;
  logic                               mux_4_gpio_11;
  logic                               mux_4_gpio_12;
  logic                               mux_4_gpio_13;
  logic                               mux_4_gpio_14;
  logic                               mux_4_gpio_15;
  logic                               mux_4_gpio_16;
  logic                               mux_4_gpio_17;
  logic                               mux_4_gpio_18;
  logic                               mux_4_gpio_19;
  logic                               mux_4_gpio_20;
  logic                               mux_4_gpio_21;

  /////////////////
  // Assignments //
  /////////////////

  // Clock
  assign w_ref_clk          = ref_clk;
  // PLL bypass
  assign w_bypass_pll       = bypass_pll;
  // External clock
  assign w_ext_clk          = ext_clk;
  // POR
`ifndef BYPASS_PLL
  assign w_pwr_on_rst_n = pwr_on_rst_n;
`else
  assign w_pwr_on_rst_n = pwr_on_ext_rst_n;
`endif
  // secure boot emulation
  assign w_secure_boot      = secure_boot;
  // Bootmode (hostd)
  // We only use 2 bits at the moment, the thirs is tied to 0
  assign w_bootmode_hostd   = {1'b0, bootmode_hostd};
  // Bootmode (safed)
  assign w_bootmode_safed   = bootmode_safed;
  // Bootmode (secd)
  assign w_bootmode_secd    = bootmode_secd;
  // JTAG (hostd)
  assign w_jtag_hostd_tck   = jtag_hostd_tck;
  assign w_jtag_hostd_tms   = jtag_hostd_tms;
  assign w_jtag_hostd_tdi   = jtag_hostd_tdi;
  assign w_jtag_hostd_trstn = jtag_hostd_trst_n;
  // TODO the pad is inverted wrt output signal, FIXME! This is just a hack,
  // some parameters in the padframe are off
  assign jtag_hostd_tdo     = w_jtag_hostd_tdo;
  // JTAG (safed)
  assign w_jtag_safed_tck   = jtag_safed_tck;
  assign w_jtag_safed_tms   = jtag_safed_tms;
  assign w_jtag_safed_tdi   = jtag_safed_tdi;
  assign w_jtag_safed_trstn = jtag_safed_trst_n;
  assign jtag_safed_tdo     = w_jtag_safed_tdo;
  // JTAG (secd)
  assign w_jtag_secd_tck    = jtag_secd_tck;
  assign w_jtag_secd_tms    = jtag_secd_tms;
  assign w_jtag_secd_tdi    = jtag_secd_tdi;
  assign w_jtag_secd_trstn  = jtag_secd_trst_n;
  assign jtag_secd_tdo      = w_jtag_secd_tdo;
  // GPIOs (hostd)
  assign w_gpio             = '0;
  // Serial Link (hostd)
  assign w_slink_hostd_rcv_clk_from_vip = slink_hostd_rcv_clk_from_vip;
  assign w_slink_hostd_from_vip         = slink_hostd_from_vip;
  assign slink_hostd_rcv_clk_to_vip     = w_slink_hostd_rcv_clk_to_vip;
  assign slink_hostd_to_vip             = w_slink_hostd_to_vip;
  // UART (hostd)
  assign uart_hostd_tx                  = w_uart_hostd_tx;
  assign w_uart_hostd_rx                = uart_hostd_rx;
  // UART (secd)
  assign uart_secd_tx                   = w_uart_secd_tx;
  assign w_uart_secd_rx                 = uart_secd_rx;
  // CAN
  // TODO connect
  assign w_can_rx                       = '0;
  // Ethernet
  // TODO connect
  assign w_eth_rxck                     = '0;
  assign w_eth_rxctl                    = '0;
  assign w_eth_rxd0                     = '0;
  assign w_eth_rxd1                     = '0;
  assign w_eth_rxd2                     = '0;
  assign w_eth_rxd3                     = '0;
  // PLL JTAG
  assign w_jtag_pll_tck                 = jtag_pll_tck;
  assign w_jtag_pll_tms                 = jtag_pll_tms;
  assign w_jtag_pll_tdi                 = jtag_pll_tdi;
  assign w_jtag_pll_trstn               = jtag_pll_trst_n;
  assign jtag_pll_tdo                   = w_jtag_pll_tdo;

  ///////////////////////////////
  // External Clock generation //
  ///////////////////////////////

  clk_rst_gen #(
    .ClkPeriod    ( ClkPeriodExt ),
    .RstClkCycles ( RstCycles    )
  ) i_ext_clk (
    .clk_o  ( ext_clk ),
`ifndef BYPASS_PLL
    .rst_no ( )
`else
    .rst_no ( pwr_on_ext_rst_n )
`endif
  );

  ////////////////////////////
  // Carfield configuration //
  ////////////////////////////

  localparam cheshire_cfg_t DutCfg = carfield_pkg::CarfieldCfgDefault;
  `CHESHIRE_TYPEDEF_ALL(, DutCfg)


`ifndef CARFIELD_CHIP_NETLIST
  astral_wrap #(
    .HypNumPhys  ( NumPhys  ),
    .HypNumChips ( NumChips )
  ) i_dut (
`else
  astral_wrap i_dut (
`endif
    // Reference clock
    .pad_periph_ref_clk_pad_i       ( w_ref_clk ),
    .pad_periph_ref_clk_pad_o       ( 1'b0 ),
    .pad_periph_fll_bypass_pad      ( w_bypass_pll ),
    // POR
    .pad_periph_pwr_on_rst_n_pad    ( w_pwr_on_rst_n ),
    // Bootmode
    .pad_periph_test_mode_pad       ( 1'b0 ),
    .pad_periph_boot_mode_0_pad     ( w_bootmode_hostd[0] ),
    .pad_periph_boot_mode_1_pad     ( w_bootmode_hostd[1] ),
    .pad_periph_secure_boot_pad     ( w_secure_boot ),
    // JTAG
    .pad_periph_jtag_tclk_pad       ( w_jtag_hostd_tck ),
    .pad_periph_jtag_trst_n_pad     ( w_jtag_hostd_tms ),
    .pad_periph_jtag_tms_pad        ( w_jtag_hostd_tdi ),
    .pad_periph_jtag_tdi_pad        ( w_jtag_hostd_trstn ),
    .pad_periph_jtag_tdo_pad        ( w_jtag_hostd_tdo ),
    // JTAG OT
    .pad_periph_jtag_ot_tclk_pad    ( w_jtag_secd_tck ),
    .pad_periph_jtag_ot_trst_ni_pad ( w_jtag_secd_tms ),
    .pad_periph_jtag_ot_tms_pad     ( w_jtag_secd_tdi ),
    .pad_periph_jtag_ot_tdi_pad     ( w_jtag_secd_trstn ),
    .pad_periph_jtag_ot_tdo_pad     ( w_jtag_secd_tdo ),
    // Hyper
    .pad_periph_hyper_cs_0_n_pad    ( w_hyper_csn[0][0] ),
    .pad_periph_hyper_cs_1_n_pad    ( w_hyper_csn[0][1] ),
    .pad_periph_hyper_ck_pad        ( w_hyper_ck[0] ),
    .pad_periph_hyper_ck_n_pad      ( w_hyper_ckn[0] ),
    .pad_periph_hyper_rwds_pad      ( w_hyper_rwds[0] ),
    .pad_periph_hyper_dq_0_pad      ( w_hyper_dq[0][0] ),
    .pad_periph_hyper_dq_1_pad      ( w_hyper_dq[0][1] ),
    .pad_periph_hyper_dq_2_pad      ( w_hyper_dq[0][2] ),
    .pad_periph_hyper_dq_3_pad      ( w_hyper_dq[0][3] ),
    .pad_periph_hyper_dq_4_pad      ( w_hyper_dq[0][4] ),
    .pad_periph_hyper_dq_5_pad      ( w_hyper_dq[0][5] ),
    .pad_periph_hyper_dq_6_pad      ( w_hyper_dq[0][6] ),
    .pad_periph_hyper_dq_7_pad      ( w_hyper_dq[0][7] ),
    .pad_periph_hyper_reset_n_pad   ( w_hyper_resetn[0] ),
    // SPW
    .pad_periph_spw_data_in_pad     ( /*TODO*/ ),
    .pad_periph_spw_strb_in_pad     ( /*TODO*/ ),
    .pad_periph_spw_data_out_pad    ( /*TODO*/ ),
    .pad_periph_spw_strb_out_pad    ( /*TODO*/ ),
    // UART
    .pad_periph_uart_tx_out_pad     ( w_uart_hostd_tx ),
    .pad_periph_uart_rx_in_pad      ( w_uart_hostd_rx ),
    // Muxed pads
    .pad_periph_muxed_v_00_pad      ( w_muxed_v_00 ),
    .pad_periph_muxed_v_01_pad      ( w_muxed_v_01 ),
    .pad_periph_muxed_v_02_pad      ( w_muxed_v_02 ),
    .pad_periph_muxed_v_03_pad      ( w_muxed_v_03 ),
    .pad_periph_muxed_v_04_pad      ( w_muxed_v_04 ),
    .pad_periph_muxed_v_05_pad      ( w_muxed_v_05 ),
    .pad_periph_muxed_v_06_pad      ( w_muxed_v_06 ),
    .pad_periph_muxed_v_07_pad      ( w_muxed_v_07 ),
    .pad_periph_muxed_v_08_pad      ( w_muxed_v_08 ),
    .pad_periph_muxed_v_09_pad      ( w_muxed_v_09 ),
    .pad_periph_muxed_v_10_pad      ( w_muxed_v_10 ),
    .pad_periph_muxed_v_11_pad      ( w_muxed_v_11 ),
    .pad_periph_muxed_v_12_pad      ( w_muxed_v_12 ),
    .pad_periph_muxed_v_13_pad      ( w_muxed_v_13 ),
    .pad_periph_muxed_v_14_pad      ( w_muxed_v_14 ),
    .pad_periph_muxed_v_15_pad      ( w_muxed_v_15 ),
    .pad_periph_muxed_v_16_pad      ( w_muxed_v_16 ),
    .pad_periph_muxed_v_17_pad      ( w_muxed_v_17 ),
    .pad_periph_muxed_v_18_pad      ( w_muxed_v_18 ),
    .pad_periph_muxed_v_19_pad      ( w_muxed_v_19 ),
    .pad_periph_muxed_v_20_pad      ( w_muxed_v_20 ),
    .pad_periph_muxed_v_21_pad      ( w_muxed_v_21 )
  );

  ////////////////////////////
  // Muxed Pads Connections //
  ////////////////////////////

  `define PAD_MUX_REG_PATH i_dut.i_astral_padframe.i_periph.i_periph_muxer.s_reg2hw

  // SPI
  assign mux_0_spih_sck = (`PAD_MUX_REG_PATH.muxed_v_00_mux_sel.q == PAD_MUX_GROUP_MUXED_V_00_SEL_SPI_SCK);
  assign mux_0_spih_csb_0 = (`PAD_MUX_REG_PATH.muxed_v_01_mux_sel.q == PAD_MUX_GROUP_MUXED_V_01_SEL_SPI_CSB_0);
  assign mux_0_spih_csb_1 = (`PAD_MUX_REG_PATH.muxed_v_02_mux_sel.q == PAD_MUX_GROUP_MUXED_V_02_SEL_SPI_CSB_1);
  assign mux_0_spih_sd_0 = (`PAD_MUX_REG_PATH.muxed_v_03_mux_sel.q == PAD_MUX_GROUP_MUXED_V_03_SEL_SPI_SD_0);
  assign mux_0_spih_sd_1 = (`PAD_MUX_REG_PATH.muxed_v_04_mux_sel.q == PAD_MUX_GROUP_MUXED_V_04_SEL_SPI_SD_1);
  assign mux_0_spih_sd_2 = (`PAD_MUX_REG_PATH.muxed_v_05_mux_sel.q == PAD_MUX_GROUP_MUXED_V_05_SEL_SPI_SD_2);
  assign mux_0_spih_sd_3 = (`PAD_MUX_REG_PATH.muxed_v_06_mux_sel.q == PAD_MUX_GROUP_MUXED_V_06_SEL_SPI_SD_3);
  tranif1 tran_spih_sck (w_muxed_v_00, w_spi_hostd_sck, mux_0_spih_sck);
  tranif1 tran_spih_csb_0 (w_muxed_v_01, w_spi_hostd_csb[0], mux_0_spih_csb_0);
  tranif1 tran_spih_csb_1 (w_muxed_v_02, w_spi_hostd_csb[1], mux_0_spih_csb_1);
  tranif1 tran_spih_sd_0 (w_muxed_v_03, w_spi_hostd_sd[0], mux_0_spih_sd_0);
  tranif1 tran_spih_sd_1 (w_muxed_v_04, w_spi_hostd_sd[1], mux_0_spih_sd_1);
  tranif1 tran_spih_sd_2 (w_muxed_v_05, w_spi_hostd_sd[2], mux_0_spih_sd_2);
  tranif1 tran_spih_sd_3 (w_muxed_v_06, w_spi_hostd_sd[3], mux_0_spih_sd_3);
  // Ethernet
  assign mux_0_eth_rxck = (`PAD_MUX_REG_PATH.muxed_v_07_mux_sel.q == PAD_MUX_GROUP_MUXED_V_07_SEL_ETHERNET_RXCK);
  assign mux_0_eth_rxctl = (`PAD_MUX_REG_PATH.muxed_v_08_mux_sel.q == PAD_MUX_GROUP_MUXED_V_08_SEL_ETHERNET_RXCTL);
  assign mux_0_eth_rxd_0 = (`PAD_MUX_REG_PATH.muxed_v_09_mux_sel.q == PAD_MUX_GROUP_MUXED_V_09_SEL_ETHERNET_RXD_0);
  assign mux_0_eth_rxd_1 = (`PAD_MUX_REG_PATH.muxed_v_10_mux_sel.q == PAD_MUX_GROUP_MUXED_V_10_SEL_ETHERNET_RXD_1);
  assign mux_0_eth_rxd_2 = (`PAD_MUX_REG_PATH.muxed_v_11_mux_sel.q == PAD_MUX_GROUP_MUXED_V_11_SEL_ETHERNET_RXD_2);
  assign mux_0_eth_rxd_3 = (`PAD_MUX_REG_PATH.muxed_v_12_mux_sel.q == PAD_MUX_GROUP_MUXED_V_12_SEL_ETHERNET_RXD_3);
  assign mux_0_eth_txck = (`PAD_MUX_REG_PATH.muxed_v_13_mux_sel.q == PAD_MUX_GROUP_MUXED_V_13_SEL_ETHERNET_TXCK);
  assign mux_0_eth_txctl = (`PAD_MUX_REG_PATH.muxed_v_14_mux_sel.q == PAD_MUX_GROUP_MUXED_V_14_SEL_ETHERNET_TXCTL);
  assign mux_0_eth_txd_0 = (`PAD_MUX_REG_PATH.muxed_v_15_mux_sel.q == PAD_MUX_GROUP_MUXED_V_15_SEL_ETHERNET_TXD_0);
  assign mux_0_eth_txd_1 = (`PAD_MUX_REG_PATH.muxed_v_16_mux_sel.q == PAD_MUX_GROUP_MUXED_V_16_SEL_ETHERNET_TXD_1);
  assign mux_0_eth_txd_2 = (`PAD_MUX_REG_PATH.muxed_v_17_mux_sel.q == PAD_MUX_GROUP_MUXED_V_17_SEL_ETHERNET_TXD_2);
  assign mux_0_eth_txd_3 = (`PAD_MUX_REG_PATH.muxed_v_18_mux_sel.q == PAD_MUX_GROUP_MUXED_V_18_SEL_ETHERNET_TXD_3);
  assign mux_0_eth_md = (`PAD_MUX_REG_PATH.muxed_v_19_mux_sel.q == PAD_MUX_GROUP_MUXED_V_19_SEL_ETHERNET_MD);
  assign mux_0_eth_mdc = (`PAD_MUX_REG_PATH.muxed_v_20_mux_sel.q == PAD_MUX_GROUP_MUXED_V_20_SEL_ETHERNET_MDC);
  assign mux_0_eth_rst_n = (`PAD_MUX_REG_PATH.muxed_v_21_mux_sel.q == PAD_MUX_GROUP_MUXED_V_21_SEL_ETHERNET_RST_N);
  tranif1 tran_eth_rxck (w_muxed_v_07, w_eth_rxck, mux_0_eth_rxck);
  tranif1 tran_eth_rxctl (w_muxed_v_08, w_eth_rxctl, mux_0_eth_rxctl);
  tranif1 tran_eth_rxd_0 (w_muxed_v_09, w_eth_rxd0, mux_0_eth_rxd_0);
  tranif1 tran_eth_rxd_1 (w_muxed_v_10, w_eth_rxd1, mux_0_eth_rxd_1);
  tranif1 tran_eth_rxd_2 (w_muxed_v_11, w_eth_rxd2, mux_0_eth_rxd_2);
  tranif1 tran_eth_rxd_3 (w_muxed_v_12, w_eth_rxd3, mux_0_eth_rxd_3);
  tranif1 tran_eth_txck (w_muxed_v_13, w_eth_txck, mux_0_eth_txck);
  tranif1 tran_eth_txctl (w_muxed_v_14, w_eth_txctl, mux_0_eth_txctl);
  tranif1 tran_eth_txd_0 (w_muxed_v_15, w_eth_txd0, mux_0_eth_txd_0);
  tranif1 tran_eth_txd_1 (w_muxed_v_16, w_eth_txd1, mux_0_eth_txd_1);
  tranif1 tran_eth_txd_2 (w_muxed_v_17, w_eth_txd2, mux_0_eth_txd_2);
  tranif1 tran_eth_txd_3 (w_muxed_v_18, w_eth_txd3, mux_0_eth_txd_3);
  tranif1 tran_eth_md (w_muxed_v_19, w_eth_md, mux_0_eth_md);
  tranif1 tran_eth_mdc (w_muxed_v_20, w_eth_mdc, mux_0_eth_mdc);
  tranif1 tran_eth_rst_n (w_muxed_v_21, w_eth_rst, mux_0_eth_rst_n);
  // CAN
  assign mux_1_can_rx = (`PAD_MUX_REG_PATH.muxed_v_00_mux_sel.q == PAD_MUX_GROUP_MUXED_V_00_SEL_CAN_RX);
  assign mux_1_can_tx = (`PAD_MUX_REG_PATH.muxed_v_01_mux_sel.q == PAD_MUX_GROUP_MUXED_V_01_SEL_CAN_TX);
  tranif1 tran_can_rx (w_muxed_v_00, w_can_rx, mux_1_can_rx);
  tranif1 tran_can_tx (w_muxed_v_01, w_can_tx, mux_1_can_tx);
  // Serial Link
  assign mux_1_slink_rcv_clk_i = (`PAD_MUX_REG_PATH.muxed_v_04_mux_sel.q == PAD_MUX_GROUP_MUXED_V_04_SEL_SERIAL_LINK_RCV_CLK_I);
  assign mux_1_slink_0_i = (`PAD_MUX_REG_PATH.muxed_v_05_mux_sel.q == PAD_MUX_GROUP_MUXED_V_05_SEL_SERIAL_LINK_I_0);
  assign mux_1_slink_1_i = (`PAD_MUX_REG_PATH.muxed_v_06_mux_sel.q == PAD_MUX_GROUP_MUXED_V_06_SEL_SERIAL_LINK_I_1);
  assign mux_1_slink_2_i = (`PAD_MUX_REG_PATH.muxed_v_07_mux_sel.q == PAD_MUX_GROUP_MUXED_V_07_SEL_SERIAL_LINK_I_2);
  assign mux_1_slink_3_i = (`PAD_MUX_REG_PATH.muxed_v_08_mux_sel.q == PAD_MUX_GROUP_MUXED_V_08_SEL_SERIAL_LINK_I_3);
  assign mux_1_slink_4_i = (`PAD_MUX_REG_PATH.muxed_v_09_mux_sel.q == PAD_MUX_GROUP_MUXED_V_09_SEL_SERIAL_LINK_I_4);
  assign mux_1_slink_5_i = (`PAD_MUX_REG_PATH.muxed_v_10_mux_sel.q == PAD_MUX_GROUP_MUXED_V_10_SEL_SERIAL_LINK_I_5);
  assign mux_1_slink_6_i = (`PAD_MUX_REG_PATH.muxed_v_11_mux_sel.q == PAD_MUX_GROUP_MUXED_V_11_SEL_SERIAL_LINK_I_6);
  assign mux_1_slink_7_i = (`PAD_MUX_REG_PATH.muxed_v_12_mux_sel.q == PAD_MUX_GROUP_MUXED_V_12_SEL_SERIAL_LINK_I_7);
  assign mux_1_slink_rcv_clk_o = (`PAD_MUX_REG_PATH.muxed_v_13_mux_sel.q == PAD_MUX_GROUP_MUXED_V_13_SEL_SERIAL_LINK_RCV_CLK_O);
  assign mux_1_slink_0_o = (`PAD_MUX_REG_PATH.muxed_v_14_mux_sel.q == PAD_MUX_GROUP_MUXED_V_14_SEL_SERIAL_LINK_O_0);
  assign mux_1_slink_1_o = (`PAD_MUX_REG_PATH.muxed_v_15_mux_sel.q == PAD_MUX_GROUP_MUXED_V_15_SEL_SERIAL_LINK_O_1);
  assign mux_1_slink_2_o = (`PAD_MUX_REG_PATH.muxed_v_16_mux_sel.q == PAD_MUX_GROUP_MUXED_V_16_SEL_SERIAL_LINK_O_2);
  assign mux_1_slink_3_o = (`PAD_MUX_REG_PATH.muxed_v_17_mux_sel.q == PAD_MUX_GROUP_MUXED_V_17_SEL_SERIAL_LINK_O_3);
  assign mux_1_slink_4_o = (`PAD_MUX_REG_PATH.muxed_v_18_mux_sel.q == PAD_MUX_GROUP_MUXED_V_18_SEL_SERIAL_LINK_O_4);
  assign mux_1_slink_5_o = (`PAD_MUX_REG_PATH.muxed_v_19_mux_sel.q == PAD_MUX_GROUP_MUXED_V_19_SEL_SERIAL_LINK_O_5);
  assign mux_1_slink_6_o = (`PAD_MUX_REG_PATH.muxed_v_20_mux_sel.q == PAD_MUX_GROUP_MUXED_V_20_SEL_SERIAL_LINK_O_6);
  assign mux_1_slink_7_o = (`PAD_MUX_REG_PATH.muxed_v_21_mux_sel.q == PAD_MUX_GROUP_MUXED_V_21_SEL_SERIAL_LINK_O_7);
  tranif1 tran_slink_rcv_clk_i (w_muxed_v_04, w_slink_hostd_rcv_clk_from_vip, mux_1_slink_rcv_clk_i);
  tranif1 tran_slink_0_i (w_muxed_v_05, w_slink_hostd_from_vip[0], mux_1_slink_0_i);
  tranif1 tran_slink_1_i (w_muxed_v_06, w_slink_hostd_from_vip[1], mux_1_slink_1_i);
  tranif1 tran_slink_2_i (w_muxed_v_07, w_slink_hostd_from_vip[2], mux_1_slink_2_i);
  tranif1 tran_slink_3_i (w_muxed_v_08, w_slink_hostd_from_vip[3], mux_1_slink_3_i);
  tranif1 tran_slink_4_i (w_muxed_v_09, w_slink_hostd_from_vip[4], mux_1_slink_4_i);
  tranif1 tran_slink_5_i (w_muxed_v_10, w_slink_hostd_from_vip[5], mux_1_slink_5_i);
  tranif1 tran_slink_6_i (w_muxed_v_11, w_slink_hostd_from_vip[6], mux_1_slink_6_i);
  tranif1 tran_slink_7_i (w_muxed_v_12, w_slink_hostd_from_vip[7], mux_1_slink_7_i);
  tranif1 tran_slink_rcv_clk_o (w_muxed_v_13, w_slink_hostd_rcv_clk_to_vip, mux_1_slink_rcv_clk_o);
  tranif1 tran_slink_0_o (w_muxed_v_14, w_slink_hostd_to_vip[0], mux_1_slink_0_o);
  tranif1 tran_slink_1_o (w_muxed_v_15, w_slink_hostd_to_vip[1], mux_1_slink_1_o);
  tranif1 tran_slink_2_o (w_muxed_v_16, w_slink_hostd_to_vip[2], mux_1_slink_2_o);
  tranif1 tran_slink_3_o (w_muxed_v_17, w_slink_hostd_to_vip[3], mux_1_slink_3_o);
  tranif1 tran_slink_4_o (w_muxed_v_18, w_slink_hostd_to_vip[4], mux_1_slink_4_o);
  tranif1 tran_slink_5_o (w_muxed_v_19, w_slink_hostd_to_vip[5], mux_1_slink_5_o);
  tranif1 tran_slink_6_o (w_muxed_v_20, w_slink_hostd_to_vip[6], mux_1_slink_6_o);
  tranif1 tran_slink_7_o (w_muxed_v_21, w_slink_hostd_to_vip[7], mux_1_slink_7_o);
  // I2C
  assign mux_2_i2c_sda_o = (`PAD_MUX_REG_PATH.muxed_v_00_mux_sel.q == PAD_MUX_GROUP_MUXED_V_00_SEL_I2C_SDA_O);
  assign mux_2_i2c_sda_i = (`PAD_MUX_REG_PATH.muxed_v_01_mux_sel.q == PAD_MUX_GROUP_MUXED_V_01_SEL_I2C_SDA_I);
  assign mux_2_i2c_sda_en = (`PAD_MUX_REG_PATH.muxed_v_02_mux_sel.q == PAD_MUX_GROUP_MUXED_V_02_SEL_I2C_SDA_EN);
  assign mux_2_i2c_scl_o = (`PAD_MUX_REG_PATH.muxed_v_03_mux_sel.q == PAD_MUX_GROUP_MUXED_V_03_SEL_I2C_SCL_O);
  assign mux_2_i2c_scl_i = (`PAD_MUX_REG_PATH.muxed_v_04_mux_sel.q == PAD_MUX_GROUP_MUXED_V_04_SEL_I2C_SCL_I);
  assign mux_2_i2c_scl_en = (`PAD_MUX_REG_PATH.muxed_v_05_mux_sel.q == PAD_MUX_GROUP_MUXED_V_05_SEL_I2C_SCL_EN);
  tranif1 tran_i2c_sda_o (w_muxed_v_00, w_i2c_hostd_sda_o, mux_2_i2c_sda_o);
  tranif1 tran_i2c_sda_i (w_muxed_v_01, w_i2c_hostd_sda_i, mux_2_i2c_sda_i);
  tranif1 tran_i2c_sda_en (w_muxed_v_02, w_i2c_hostd_sda_en, mux_2_i2c_sda_en);
  tranif1 tran_i2c_scl_o (w_muxed_v_03, w_i2c_hostd_scl_o, mux_2_i2c_scl_o);
  tranif1 tran_i2c_scl_i (w_muxed_v_04, w_i2c_hostd_scl_i, mux_2_i2c_scl_i);
  tranif1 tran_i2c_scl_en (w_muxed_v_05, w_i2c_hostd_scl_en, mux_2_i2c_scl_en);
  bufif0(w_i2c_hostd_sda, w_i2c_hostd_sda_o, w_i2c_hostd_sda_en);
  bufif1(w_i2c_hostd_sda_i, w_i2c_hostd_sda, w_i2c_hostd_sda_en);
  bufif0(w_i2c_hostd_scl, w_i2c_hostd_scl_o, w_i2c_hostd_scl_en);
  bufif1(w_i2c_hostd_scl_i, w_i2c_hostd_scl, w_i2c_hostd_scl_en);
  // TC - TODO
  // PTME - TODO
  // HPC - TODO
  // LLC LINE - TODO
  // OBT - TODO
  // SPI OT
  assign mux_3_spih_ot_sck = (`PAD_MUX_REG_PATH.muxed_v_00_mux_sel.q == PAD_MUX_GROUP_MUXED_V_00_SEL_SPI_OT_SCK);
  assign mux_3_spih_ot_csb = (`PAD_MUX_REG_PATH.muxed_v_01_mux_sel.q == PAD_MUX_GROUP_MUXED_V_01_SEL_SPI_OT_CSB);
  assign mux_3_spih_ot_sd_0 = (`PAD_MUX_REG_PATH.muxed_v_02_mux_sel.q == PAD_MUX_GROUP_MUXED_V_02_SEL_SPI_OT_SD_0);
  assign mux_3_spih_ot_sd_1 = (`PAD_MUX_REG_PATH.muxed_v_03_mux_sel.q == PAD_MUX_GROUP_MUXED_V_03_SEL_SPI_OT_SD_1);
  assign mux_3_spih_ot_sd_2 = (`PAD_MUX_REG_PATH.muxed_v_04_mux_sel.q == PAD_MUX_GROUP_MUXED_V_04_SEL_SPI_OT_SD_2);
  assign mux_3_spih_ot_sd_3 = (`PAD_MUX_REG_PATH.muxed_v_05_mux_sel.q == PAD_MUX_GROUP_MUXED_V_05_SEL_SPI_OT_SD_3);
  tranif1 tran_spih_ot_sck (w_muxed_v_00, w_spi_secd_sck, mux_3_spih_ot_sck);
  tranif1 tran_spih_ot_csb (w_muxed_v_01, w_spi_secd_csb[0], mux_3_spih_ot_csb);
  tranif1 tran_spih_ot_sd_0 (w_muxed_v_02, w_spi_secd_sd[0], mux_3_spih_ot_sd_0);
  tranif1 tran_spih_ot_sd_1 (w_muxed_v_03, w_spi_secd_sd[1], mux_3_spih_ot_sd_1);
  tranif1 tran_spih_ot_sd_2 (w_muxed_v_04, w_spi_secd_sd[2], mux_3_spih_ot_sd_2);
  tranif1 tran_spih_ot_sd_3 (w_muxed_v_05, w_spi_secd_sd[3], mux_3_spih_ot_sd_3);
  // GPIO
  assign mux_4_gpio_0 = (`PAD_MUX_REG_PATH.muxed_v_00_mux_sel.q == PAD_MUX_GROUP_MUXED_V_00_SEL_GPIO_IO_0);
  assign mux_4_gpio_1 = (`PAD_MUX_REG_PATH.muxed_v_01_mux_sel.q == PAD_MUX_GROUP_MUXED_V_01_SEL_GPIO_IO_1);
  assign mux_4_gpio_2 = (`PAD_MUX_REG_PATH.muxed_v_02_mux_sel.q == PAD_MUX_GROUP_MUXED_V_02_SEL_GPIO_IO_2);
  assign mux_4_gpio_3 = (`PAD_MUX_REG_PATH.muxed_v_03_mux_sel.q == PAD_MUX_GROUP_MUXED_V_03_SEL_GPIO_IO_3);
  assign mux_4_gpio_4 = (`PAD_MUX_REG_PATH.muxed_v_04_mux_sel.q == PAD_MUX_GROUP_MUXED_V_04_SEL_GPIO_IO_4);
  assign mux_4_gpio_5 = (`PAD_MUX_REG_PATH.muxed_v_05_mux_sel.q == PAD_MUX_GROUP_MUXED_V_05_SEL_GPIO_IO_5);
  assign mux_4_gpio_6 = (`PAD_MUX_REG_PATH.muxed_v_06_mux_sel.q == PAD_MUX_GROUP_MUXED_V_06_SEL_GPIO_IO_6);
  assign mux_4_gpio_7 = (`PAD_MUX_REG_PATH.muxed_v_07_mux_sel.q == PAD_MUX_GROUP_MUXED_V_07_SEL_GPIO_IO_7);
  assign mux_4_gpio_8 = (`PAD_MUX_REG_PATH.muxed_v_08_mux_sel.q == PAD_MUX_GROUP_MUXED_V_08_SEL_GPIO_IO_8);
  assign mux_4_gpio_9 = (`PAD_MUX_REG_PATH.muxed_v_09_mux_sel.q == PAD_MUX_GROUP_MUXED_V_09_SEL_GPIO_IO_9);
  assign mux_4_gpio_10 = (`PAD_MUX_REG_PATH.muxed_v_10_mux_sel.q == PAD_MUX_GROUP_MUXED_V_10_SEL_GPIO_IO_10);
  assign mux_4_gpio_11 = (`PAD_MUX_REG_PATH.muxed_v_11_mux_sel.q == PAD_MUX_GROUP_MUXED_V_11_SEL_GPIO_IO_11);
  assign mux_4_gpio_12 = (`PAD_MUX_REG_PATH.muxed_v_12_mux_sel.q == PAD_MUX_GROUP_MUXED_V_12_SEL_GPIO_IO_12);
  assign mux_4_gpio_13 = (`PAD_MUX_REG_PATH.muxed_v_13_mux_sel.q == PAD_MUX_GROUP_MUXED_V_13_SEL_GPIO_IO_13);
  assign mux_4_gpio_14 = (`PAD_MUX_REG_PATH.muxed_v_14_mux_sel.q == PAD_MUX_GROUP_MUXED_V_14_SEL_GPIO_IO_14);
  assign mux_4_gpio_15 = (`PAD_MUX_REG_PATH.muxed_v_15_mux_sel.q == PAD_MUX_GROUP_MUXED_V_15_SEL_GPIO_IO_15);
  assign mux_4_gpio_16 = (`PAD_MUX_REG_PATH.muxed_v_16_mux_sel.q == PAD_MUX_GROUP_MUXED_V_16_SEL_GPIO_IO_16);
  assign mux_4_gpio_17 = (`PAD_MUX_REG_PATH.muxed_v_17_mux_sel.q == PAD_MUX_GROUP_MUXED_V_17_SEL_GPIO_IO_17);
  assign mux_4_gpio_18 = (`PAD_MUX_REG_PATH.muxed_v_18_mux_sel.q == PAD_MUX_GROUP_MUXED_V_18_SEL_GPIO_IO_18);
  assign mux_4_gpio_19 = (`PAD_MUX_REG_PATH.muxed_v_19_mux_sel.q == PAD_MUX_GROUP_MUXED_V_19_SEL_GPIO_IO_19);
  assign mux_4_gpio_20 = (`PAD_MUX_REG_PATH.muxed_v_20_mux_sel.q == PAD_MUX_GROUP_MUXED_V_20_SEL_GPIO_IO_20);
  assign mux_4_gpio_21 = (`PAD_MUX_REG_PATH.muxed_v_21_mux_sel.q == PAD_MUX_GROUP_MUXED_V_21_SEL_GPIO_IO_21);
  tranif1 tran_gpio_0 (w_muxed_v_00, w_gpio[0], mux_4_gpio_0);
  tranif1 tran_gpio_1 (w_muxed_v_01, w_gpio[1], mux_4_gpio_1);
  tranif1 tran_gpio_2 (w_muxed_v_02, w_gpio[2], mux_4_gpio_2);
  tranif1 tran_gpio_3 (w_muxed_v_03, w_gpio[3], mux_4_gpio_3);
  tranif1 tran_gpio_4 (w_muxed_v_04, w_gpio[4], mux_4_gpio_4);
  tranif1 tran_gpio_5 (w_muxed_v_05, w_gpio[5], mux_4_gpio_5);
  tranif1 tran_gpio_6 (w_muxed_v_06, w_gpio[6], mux_4_gpio_6);
  tranif1 tran_gpio_7 (w_muxed_v_07, w_gpio[7], mux_4_gpio_7);
  tranif1 tran_gpio_8 (w_muxed_v_08, w_gpio[8], mux_4_gpio_8);
  tranif1 tran_gpio_9 (w_muxed_v_09, w_gpio[9], mux_4_gpio_9);
  tranif1 tran_gpio_10 (w_muxed_v_10, w_gpio[10], mux_4_gpio_10);
  tranif1 tran_gpio_11 (w_muxed_v_11, w_gpio[11], mux_4_gpio_11);
  tranif1 tran_gpio_12 (w_muxed_v_12, w_gpio[12], mux_4_gpio_12);
  tranif1 tran_gpio_13 (w_muxed_v_13, w_gpio[13], mux_4_gpio_13);
  tranif1 tran_gpio_14 (w_muxed_v_14, w_gpio[14], mux_4_gpio_14);
  tranif1 tran_gpio_15 (w_muxed_v_15, w_gpio[15], mux_4_gpio_15);
  tranif1 tran_gpio_16 (w_muxed_v_16, w_gpio[16], mux_4_gpio_16);
  tranif1 tran_gpio_17 (w_muxed_v_17, w_gpio[17], mux_4_gpio_17);
  tranif1 tran_gpio_18 (w_muxed_v_18, w_gpio[18], mux_4_gpio_18);
  tranif1 tran_gpio_19 (w_muxed_v_19, w_gpio[19], mux_4_gpio_19);
  tranif1 tran_gpio_20 (w_muxed_v_20, w_gpio[20], mux_4_gpio_20);
  tranif1 tran_gpio_21 (w_muxed_v_21, w_gpio[21], mux_4_gpio_21);
  
  for (genvar i = 0; i < 4; ++i) begin : gen_spih_sd_io
    pullup (w_spi_hostd_sd[i]);
  end

  for (genvar i = 0; i < SpihNumCs; ++i) begin : gen_spih_cs_io
    pullup (w_spi_hostd_csb[i]);
  end

  for (genvar i = 0 ; i<NumPhys; i++) begin : gen_hyper_phy
    pullup (w_hyper_rwds[i]);
  end

  //////////////////
  // Carfield VIP //
  //////////////////

  localparam int unsigned SafedNumAxiExtMstPorts   = 1;
  localparam int unsigned PulpClNumAxiExtMstPorts  = 0;
  localparam int unsigned SpatzClNumAxiExtMstPorts = 0;
  localparam int unsigned CarNumAxiExtSlvPorts     = SafedNumAxiExtMstPorts + PulpClNumAxiExtMstPorts + SpatzClNumAxiExtMstPorts;

  axi_mst_req_t [CarNumAxiExtSlvPorts-1:0] ext_to_vip_req;
  axi_mst_rsp_t [CarNumAxiExtSlvPorts-1:0] ext_to_vip_rsp;

  axi_mst_req_t axi_muxed_req;
  axi_mst_rsp_t axi_muxed_rsp;

  // Verification IPs for carfield
  vip_carfield_soc #(
    .DutCfg        ( DutCfg ),
    // Determine whether we preload the hyperram model or not User preload. If 0, the memory model
    // is not preloaded at time 0.
    .HypUserPreload ( `HYP_USER_PRELOAD ),
    // Mem files for hyperram model. The argument is considered only if HypUserPreload==1 in the
    // memory model.
    .Hyp0UserPreloadMemFile ( `HYP0_PRELOAD_MEM_FILE ),
    .Hyp1UserPreloadMemFile ( `HYP1_PRELOAD_MEM_FILE ),
    .ClkPeriodSys  ( ClkPeriodRef ),
    .ClkPeriodJtag ( ClkPeriodJtag ),
    .RstCycles     ( RstCyclesVip ),
    .TAppl         ( TAppl ),
    .TTest         ( TTest ),
    .NumAxiExtSlvPorts ( CarNumAxiExtSlvPorts ),
    .axi_slv_ext_req_t ( axi_mst_req_t ),
    .axi_slv_ext_rsp_t ( axi_mst_rsp_t )
  ) car_vip (
    // We use the clock/reset generated in cheshire VIP
    .clk_vip   (),
    .rst_n_vip (),
    .pad_hyper_csn ( w_hyper_csn ),
    .pad_hyper_ck  ( w_hyper_ck  ),
    .pad_hyper_ckn ( w_hyper_ckn ),
    .pad_hyper_rwds  ( w_hyper_rwds ),
    .pad_hyper_resetn ( w_hyper_resetn ),
    .pad_hyper_dq (w_hyper_dq ),
    // Multiplex incoming AXI req/rsp and convert t
    // hrough serial link
    .axi_slvs_req ( ext_to_vip_req ),
    .axi_slvs_rsp ( ext_to_vip_rsp ),
    .axi_muxed_req ( axi_muxed_req ),
    .axi_muxed_rsp ( axi_muxed_rsp )
  );

  //////////////////
  // Cheshire VIP //
  //////////////////

  // VIP
  vip_cheshire_soc #(
    .DutCfg            ( DutCfg ),
    .axi_ext_llc_req_t ( axi_llc_req_t ),
    .axi_ext_llc_rsp_t ( axi_llc_rsp_t ),
    .axi_ext_mst_req_t ( axi_mst_req_t ),
    .axi_ext_mst_rsp_t ( axi_mst_rsp_t ),
    .ClkPeriodSys      ( ClkPeriodRef  ),
    .ClkPeriodJtag     ( ClkPeriodJtag ),
    .RstCycles         ( RstCyclesVip ),
    .TAppl             ( TAppl ),
    .TTest             ( TTest ),
    .SlinkAxiDebug     ( 0     ),
    .UartBaudRate      ( 57600 )  // Vadid for 50MHz clock. If the actual clock, clk, is clk = a*50MHz the the baudrate, UartBaudRate, should be UartBaudRate = a*57600
  ) chs_vip (
    // Generate reference clock for the PLL
    .clk             ( ref_clk                ),
    // Generate reset
    .rst_n           ( pwr_on_rst_n           ),
    .test_mode       ( testmode_hostd         ),
    .boot_mode       ( bootmode_hostd         ),
    // In carfield chip, the real-time clock is generated by the PLL
    .rtc             ( /* unconnected */      ),
    // In carfield chip, we do not connect to axi_sim_mem, but to HyperRAM
    .axi_llc_mst_req ( '0 ),
    .axi_llc_mst_rsp (    ),
     // External AXI port
    .axi_slink_mst_req ( axi_muxed_req ),
    .axi_slink_mst_rsp ( axi_muxed_rsp ),
    // JTAG interface
    .jtag_tck        ( jtag_hostd_tck   ),
    .jtag_trst_n     ( jtag_hostd_trst_n ),
    .jtag_tms        ( jtag_hostd_tms   ),
    .jtag_tdi        ( jtag_hostd_tdi   ),
    .jtag_tdo        ( jtag_hostd_tdo   ),
    // UART interface
    .uart_tx         ( uart_hostd_tx ),
    .uart_rx         ( uart_hostd_rx ),
    // I2C interface
    .i2c_sda         ( w_i2c_hostd_sda ),
    .i2c_scl         ( w_i2c_hostd_scl ),
    // SPI host interface
    .spih_sck        ( w_spi_hostd_sck ),
    .spih_csb        ( w_spi_hostd_csb ),
    .spih_sd         ( w_spi_hostd_sd  ),
    // Serial link interface
    .slink_rcv_clk_i ( slink_hostd_rcv_clk_from_vip ),
    .slink_rcv_clk_o ( slink_hostd_rcv_clk_to_vip   ),
    .slink_i         ( slink_hostd_from_vip         ),
    .slink_o         ( slink_hostd_to_vip           )
  );

  ///////////////////////
  // Safety island VIP //
  ///////////////////////

  if (CarfieldIslandsCfg.safed.enable) begin : gen_safed_vip
    localparam time ClkPeriodSafedJtag = ClkPeriodRef * 2;

    localparam axi_in_t AxiIn = gen_axi_in(DutCfg);
    localparam int unsigned AxiSlvIdWidth = DutCfg.AxiMstIdWidth + $clog2(AxiIn.num_in);

    // VIP
    vip_safety_island_soc #(
      .DutCfg            ( SafetyIslandCfg ),
      .axi_mst_ext_req_t ( axi_mst_req_t ),
      .axi_mst_ext_rsp_t ( axi_mst_rsp_t ),
      .axi_slv_ext_req_t ( axi_mst_req_t ),
      .axi_slv_ext_rsp_t ( axi_mst_rsp_t ),
      .GlobalAddrWidth   ( 32            ),
      .BaseAddr          ( 32'h6000_0000 ),
      .AddrRange         ( CarfieldIslandsCfg.safed.size      ),
      .MemOffset         ( SafetyIslandMemOffset ),
      .PeriphOffset      ( SafetyIslandPerOffset ),
      .ClkPeriodSys      ( ClkPeriodRef          ),
      .ClkPeriodJtag     ( ClkPeriodSafedJtag    ),
      .RstCycles         ( RstCyclesVip             ),
      .AxiDataWidth      ( DutCfg.AxiDataWidth   ),
      .AxiAddrWidth      ( DutCfg.AddrWidth      ),
      .AxiInputIdWidth   ( AxiSlvIdWidth         ),
      .AxiOutputIdWidth  ( DutCfg.AxiMstIdWidth  ),
      .AxiUserWidth      ( DutCfg.AxiUserWidth   ),
      .AxiDebug          ( 0     ),
      .ApplFrac          ( TAppl ),
      .TestFrac          ( TTest )
    ) safed_vip (
      // we use the clock generated in cheshire VIP
      .clk_vip      (),
      .ext_clk_vip  (),
      // we use the reset generated in cheshire VIP
      .rst_n_vip    (),
      .test_mode    (),
      .boot_mode    ( bootmode_safed ),
      // we use the rtc generated in cheshire VIP
      .rtc          (),
      // Not used in carfield
      .axi_mst_req  ( '0 ),
      .axi_mst_rsp  (    ),
      // Virtual driver to be multiplexed and then serialized through the serial link
      .axi_slv_req  ( ext_to_vip_req[SafedNumAxiExtMstPorts-1:0] ),
      .axi_slv_rsp  ( ext_to_vip_rsp[SafedNumAxiExtMstPorts-1:0] ),
      // JTAG interface
      .jtag_tck     ( jtag_safed_tck    ),
      .jtag_trst_n  ( jtag_safed_trst_n ),
      .jtag_tms     ( jtag_safed_tms    ),
      .jtag_tdi     ( jtag_safed_tdi    ),
      .jtag_tdo     ( jtag_safed_tdo    ),
      // Exit
      .exit_status  ( )
    );
  end else begin: gen_no_safed_vip
    assign jtag_safed_tck    = '0;
    assign jtag_safed_trst_n = '0;
    assign jtag_safed_tms    = '0;
    assign jtag_safed_tdi    = '0;
    assign bootmode_safed    = '0;
  end

  /////////////////////////
  // Security island VIP //
  /////////////////////////

  if (CarfieldIslandsCfg.secured.enable) begin: gen_scured_vip
    localparam time ClkPeriodSecdJtag = ClkPeriodRef * 2;

    // VIP
    vip_security_island_soc #(
      .ClkPeriodJtag ( ClkPeriodSecdJtag ),
      .RstCycles     ( RstCyclesVip ),
      .TAppl         ( TAppl ),
      .TTest         ( TTest )
    ) secd_vip (
      .clk_vip      ( ),
      .rst_n_vip    ( ),
      .bootmode     ( bootmode_secd   ),
      // UART interface
      .uart_tx      ( uart_secd_tx     ),
      .uart_rx      ( uart_secd_rx     ),
      // JTAG interface
      .jtag_tck     ( jtag_secd_tck    ),
      .jtag_trst_n  ( jtag_secd_trst_n ),
      .jtag_tms     ( jtag_secd_tms    ),
      .jtag_tdi     ( jtag_secd_tdi    ),
      .jtag_tdo     ( jtag_secd_tdo    ),
      .SPI_D0       ( w_spi_secd_sd[0] ),
      .SPI_D1       ( w_spi_secd_sd[1] ),
      .SPI_SCK      ( w_spi_secd_sck   ),
      .SPI_CSB      ( w_spi_secd_csb[0])
    );
  end else begin
    assign bootmode_secd = '0;
  end

  /////////////////////////
  // PLL JTAG verif      //
  /////////////////////////

  localparam time ClkPeriodPllJtag  = ClkPeriodRef * 2;
  localparam int PLL_JTAG_IR_BYPASS = 'h0;
  localparam int PLL_JTAG_IR_IDCODE = 'h1;
  localparam int PLL_JTAG_IR_PLLREG = 'h10;

  // Generate clock for JTAG
  clk_rst_gen #(
    .ClkPeriod    ( ClkPeriodPllJtag ),
    .RstClkCycles ( RstCyclesVip        )
  ) i_clk_jtag (
    .clk_o  ( jtag_pll_tck ),
    .rst_no ( )
  );

  VJTAG_DV vjtag_pll(jtag_pll_tck);

  typedef vjtag_test::vjtag_driver #(
    .IrLength( 5                        ),
    .IrIDCODE( PLL_JTAG_IR_IDCODE       ),
    .TA      ( ClkPeriodPllJtag * TAppl ),
    .TT      ( ClkPeriodPllJtag * TTest )
  ) vjtag_driver_t;

  vjtag_driver_t vjtag_pll_dv = new(vjtag_pll);

  initial begin
    vjtag_pll_dv.reset_master();
  end

  assign jtag_pll_trst_n = vjtag_pll.trst_n;
  assign jtag_pll_tms = vjtag_pll.tms;
  assign jtag_pll_tdi = vjtag_pll.tdi;
  assign vjtag_pll.tdo = jtag_pll_tdo;


  /////////////////////////
  // Carfield chip tasks //
  /////////////////////////

  // PLL bypass mode
  task set_bypass_pll(input logic bypass);
    bypass_pll = bypass;
  endtask

  task set_secure_boot(input logic sb);
    secure_boot = sb;
  endtask // set_secure_boot

  // PLL frequency meters
  localparam MaxSample = 1024;
  logic [NumPlls-1:0] print_freq_debug_signals, print_freq_pll_out;
  real  sampled_freq_debug_signals [NumPlls-1:0];
  real  sampled_freq_pll_out [NumPlls-1:0];

  for(genvar p=0; p<NumPlls; p++) begin
    freq_meter #(
      .MAX_SAMPLE ( MaxSample )
    ) i_freq_meter_debug_signals (
      .clk        ( debug_signals[p]),
      .print_freq ( print_freq_debug_signals[p]   ),
      .freq       ( sampled_freq_debug_signals[p] )
    );

    //TODO: how should this be managed??? PLL, FLL???
    // freq_meter #(
    //   .MAX_SAMPLE ( MaxSample )
    // ) i_freq_meter_pll_out (
    //   .clk        ( i_dut.i_pll.clkpll_o[p] ),
    //   .print_freq ( print_freq_pll_out[p]   ),
    //   .freq       ( sampled_freq_pll_out[p] )
    // );
  end

  task sample_freq_debug_signals ();
     for(int i=0; i<NumPlls; i++) begin
         repeat(MaxSample*2)
           @(posedge debug_signals[i]);

         @(posedge print_freq_debug_signals[i]);

         $display("Sampling debug signal %d. Measured frequency: %f MHz\n", i, sampled_freq_debug_signals[i]*10);
     end
  endtask

  //TODO: how should this be managed??? PLL, FLL???
  // task sample_freq_pll_out ();
  //    for(int i=0; i<NumPlls; i++) begin
  //        repeat(MaxSample*2)
  //          @(posedge  i_dut.i_pll.clkpll_o[i]);

  //        @(posedge print_freq_pll_out[i]);

  //        $display("Sampling PLL output %d. Measured frequency: %f MHz\n", i, sampled_freq_pll_out[i]*10);
  //    end
  // endtask

  task check_freq_pll_out (
    input real sampled_freq_pll_out,
    input int  desired_freq
  );
     real     diff_freq;
     diff_freq = sampled_freq_pll_out - real'(desired_freq);
     diff_freq = (diff_freq/sampled_freq_pll_out)*100;

     if((diff_freq < -5) | (diff_freq > 5))
       $fatal(1,"More than 5 percent of difference between actual and desired frequency! %f vs %d", sampled_freq_pll_out, desired_freq);
     else
       $display("Desired: %f actual: %d", desired_freq, sampled_freq_pll_out);
  endtask

  ///////////////////
  // Generic tasks //
  ///////////////////

  task passthrough_or_wait_for_secd_hw_init();
`ifndef CARFIELD_CHIP_NETLIST
    if ((secure_boot || !i_dut.i_dut.car_regs_hw2reg.security_island_isolate_status.d) &&
        i_dut.i_dut.gen_secure_subsystem.i_security_island.u_RoT.u_rv_core_ibex.fetch_enable != lc_ctrl_pkg::On) begin
      $display("Wait for OT to boot...");
      wait (i_dut.i_dut.gen_secure_subsystem.i_security_island.u_RoT.u_rv_core_ibex.fetch_enable == lc_ctrl_pkg::On);
    end
`endif
  endtask

  task automatic slink_read_reg(
    input doub_bt addr,
    output word_bt data,
    input int unsigned idle_cycles
  );
    axi_data_t beats [$];
    #(ClkPeriodRef * idle_cycles);
    chs_vip.slink_read_beats(addr, 2, 0, beats);
    data = beats[0];
  endtask

  task wait_fll_lock();
    @(posedge i_dut.fll_lock);
    @(posedge i_dut.clk_fll_out);
  endtask: wait_fll_lock

  task automatic configure_sl_pad(ref bit jtag_check_write);
    chs_vip.jtag_write_reg32(PAD_CFG_ADDR + ASTRAL_PADFRAME_PERIPH_CONFIG_MUXED_V_04_MUX_SEL_OFFSET, PAD_MUX_GROUP_MUXED_V_04_SEL_SERIAL_LINK_RCV_CLK_I, jtag_check_write);
    chs_vip.jtag_write_reg32(PAD_CFG_ADDR + ASTRAL_PADFRAME_PERIPH_CONFIG_MUXED_V_05_MUX_SEL_OFFSET, PAD_MUX_GROUP_MUXED_V_05_SEL_SERIAL_LINK_I_0, jtag_check_write);
    chs_vip.jtag_write_reg32(PAD_CFG_ADDR + ASTRAL_PADFRAME_PERIPH_CONFIG_MUXED_V_06_MUX_SEL_OFFSET, PAD_MUX_GROUP_MUXED_V_06_SEL_SERIAL_LINK_I_1, jtag_check_write);
    chs_vip.jtag_write_reg32(PAD_CFG_ADDR + ASTRAL_PADFRAME_PERIPH_CONFIG_MUXED_V_07_MUX_SEL_OFFSET, PAD_MUX_GROUP_MUXED_V_07_SEL_SERIAL_LINK_I_2, jtag_check_write);
    chs_vip.jtag_write_reg32(PAD_CFG_ADDR + ASTRAL_PADFRAME_PERIPH_CONFIG_MUXED_V_08_MUX_SEL_OFFSET, PAD_MUX_GROUP_MUXED_V_08_SEL_SERIAL_LINK_I_3, jtag_check_write);
    chs_vip.jtag_write_reg32(PAD_CFG_ADDR + ASTRAL_PADFRAME_PERIPH_CONFIG_MUXED_V_09_MUX_SEL_OFFSET, PAD_MUX_GROUP_MUXED_V_09_SEL_SERIAL_LINK_I_4, jtag_check_write);
    chs_vip.jtag_write_reg32(PAD_CFG_ADDR + ASTRAL_PADFRAME_PERIPH_CONFIG_MUXED_V_10_MUX_SEL_OFFSET, PAD_MUX_GROUP_MUXED_V_10_SEL_SERIAL_LINK_I_5, jtag_check_write);
    chs_vip.jtag_write_reg32(PAD_CFG_ADDR + ASTRAL_PADFRAME_PERIPH_CONFIG_MUXED_V_11_MUX_SEL_OFFSET, PAD_MUX_GROUP_MUXED_V_11_SEL_SERIAL_LINK_I_6, jtag_check_write);
    chs_vip.jtag_write_reg32(PAD_CFG_ADDR + ASTRAL_PADFRAME_PERIPH_CONFIG_MUXED_V_12_MUX_SEL_OFFSET, PAD_MUX_GROUP_MUXED_V_12_SEL_SERIAL_LINK_I_7, jtag_check_write);
    chs_vip.jtag_write_reg32(PAD_CFG_ADDR + ASTRAL_PADFRAME_PERIPH_CONFIG_MUXED_V_13_MUX_SEL_OFFSET, PAD_MUX_GROUP_MUXED_V_13_SEL_SERIAL_LINK_RCV_CLK_O, jtag_check_write);
    chs_vip.jtag_write_reg32(PAD_CFG_ADDR + ASTRAL_PADFRAME_PERIPH_CONFIG_MUXED_V_14_MUX_SEL_OFFSET, PAD_MUX_GROUP_MUXED_V_14_SEL_SERIAL_LINK_O_0, jtag_check_write);
    chs_vip.jtag_write_reg32(PAD_CFG_ADDR + ASTRAL_PADFRAME_PERIPH_CONFIG_MUXED_V_15_MUX_SEL_OFFSET, PAD_MUX_GROUP_MUXED_V_15_SEL_SERIAL_LINK_O_1, jtag_check_write);
    chs_vip.jtag_write_reg32(PAD_CFG_ADDR + ASTRAL_PADFRAME_PERIPH_CONFIG_MUXED_V_16_MUX_SEL_OFFSET, PAD_MUX_GROUP_MUXED_V_16_SEL_SERIAL_LINK_O_2, jtag_check_write);
    chs_vip.jtag_write_reg32(PAD_CFG_ADDR + ASTRAL_PADFRAME_PERIPH_CONFIG_MUXED_V_17_MUX_SEL_OFFSET, PAD_MUX_GROUP_MUXED_V_17_SEL_SERIAL_LINK_O_3, jtag_check_write);
    chs_vip.jtag_write_reg32(PAD_CFG_ADDR + ASTRAL_PADFRAME_PERIPH_CONFIG_MUXED_V_18_MUX_SEL_OFFSET, PAD_MUX_GROUP_MUXED_V_18_SEL_SERIAL_LINK_O_4, jtag_check_write);
    chs_vip.jtag_write_reg32(PAD_CFG_ADDR + ASTRAL_PADFRAME_PERIPH_CONFIG_MUXED_V_19_MUX_SEL_OFFSET, PAD_MUX_GROUP_MUXED_V_19_SEL_SERIAL_LINK_O_5, jtag_check_write);
    chs_vip.jtag_write_reg32(PAD_CFG_ADDR + ASTRAL_PADFRAME_PERIPH_CONFIG_MUXED_V_20_MUX_SEL_OFFSET, PAD_MUX_GROUP_MUXED_V_20_SEL_SERIAL_LINK_O_6, jtag_check_write);
    chs_vip.jtag_write_reg32(PAD_CFG_ADDR + ASTRAL_PADFRAME_PERIPH_CONFIG_MUXED_V_21_MUX_SEL_OFFSET, PAD_MUX_GROUP_MUXED_V_21_SEL_SERIAL_LINK_O_7, jtag_check_write);
  endtask: configure_sl_pad

  task automatic configure_spi_pad(ref bit jtag_check_write);
    chs_vip.jtag_write_reg32(PAD_CFG_ADDR + ASTRAL_PADFRAME_PERIPH_CONFIG_MUXED_V_00_MUX_SEL_OFFSET, PAD_MUX_GROUP_MUXED_V_00_SEL_SPI_SCK, jtag_check_write);
    chs_vip.jtag_write_reg32(PAD_CFG_ADDR + ASTRAL_PADFRAME_PERIPH_CONFIG_MUXED_V_01_MUX_SEL_OFFSET, PAD_MUX_GROUP_MUXED_V_01_SEL_SPI_CSB_0, jtag_check_write);
    chs_vip.jtag_write_reg32(PAD_CFG_ADDR + ASTRAL_PADFRAME_PERIPH_CONFIG_MUXED_V_02_MUX_SEL_OFFSET, PAD_MUX_GROUP_MUXED_V_02_SEL_SPI_CSB_1, jtag_check_write);
    chs_vip.jtag_write_reg32(PAD_CFG_ADDR + ASTRAL_PADFRAME_PERIPH_CONFIG_MUXED_V_03_MUX_SEL_OFFSET, PAD_MUX_GROUP_MUXED_V_03_SEL_SPI_SD_0, jtag_check_write);
    chs_vip.jtag_write_reg32(PAD_CFG_ADDR + ASTRAL_PADFRAME_PERIPH_CONFIG_MUXED_V_04_MUX_SEL_OFFSET, PAD_MUX_GROUP_MUXED_V_04_SEL_SPI_SD_1, jtag_check_write);
    chs_vip.jtag_write_reg32(PAD_CFG_ADDR + ASTRAL_PADFRAME_PERIPH_CONFIG_MUXED_V_05_MUX_SEL_OFFSET, PAD_MUX_GROUP_MUXED_V_05_SEL_SPI_SD_2, jtag_check_write);
    chs_vip.jtag_write_reg32(PAD_CFG_ADDR + ASTRAL_PADFRAME_PERIPH_CONFIG_MUXED_V_06_MUX_SEL_OFFSET, PAD_MUX_GROUP_MUXED_V_06_SEL_SPI_SD_3, jtag_check_write);
  endtask: configure_spi_pad

  task automatic configure_i2c_pad(ref bit jtag_check_write);
    chs_vip.jtag_write_reg32(PAD_CFG_ADDR + ASTRAL_PADFRAME_PERIPH_CONFIG_MUXED_V_00_MUX_SEL_OFFSET, PAD_MUX_GROUP_MUXED_V_00_SEL_I2C_SDA_O, jtag_check_write);
    chs_vip.jtag_write_reg32(PAD_CFG_ADDR + ASTRAL_PADFRAME_PERIPH_CONFIG_MUXED_V_01_MUX_SEL_OFFSET, PAD_MUX_GROUP_MUXED_V_01_SEL_I2C_SDA_I, jtag_check_write);
    chs_vip.jtag_write_reg32(PAD_CFG_ADDR + ASTRAL_PADFRAME_PERIPH_CONFIG_MUXED_V_02_MUX_SEL_OFFSET, PAD_MUX_GROUP_MUXED_V_02_SEL_I2C_SDA_EN, jtag_check_write);
    chs_vip.jtag_write_reg32(PAD_CFG_ADDR + ASTRAL_PADFRAME_PERIPH_CONFIG_MUXED_V_03_MUX_SEL_OFFSET, PAD_MUX_GROUP_MUXED_V_03_SEL_I2C_SCL_O, jtag_check_write);
    chs_vip.jtag_write_reg32(PAD_CFG_ADDR + ASTRAL_PADFRAME_PERIPH_CONFIG_MUXED_V_04_MUX_SEL_OFFSET, PAD_MUX_GROUP_MUXED_V_04_SEL_I2C_SCL_I, jtag_check_write);
    chs_vip.jtag_write_reg32(PAD_CFG_ADDR + ASTRAL_PADFRAME_PERIPH_CONFIG_MUXED_V_05_MUX_SEL_OFFSET, PAD_MUX_GROUP_MUXED_V_05_SEL_I2C_SCL_EN, jtag_check_write);
  endtask: configure_i2c_pad

endmodule: astral_fixture