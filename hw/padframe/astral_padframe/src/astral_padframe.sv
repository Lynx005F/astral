
// File auto-generated by Padrick unknown
module astral_padframe
  import pkg_astral_padframe::*;
#(
  parameter int unsigned   AW = 32,
  parameter int unsigned   DW = 32,
  parameter type req_t = logic, // reg_interface request type
  parameter type resp_t = logic, // reg_interface response type
  parameter logic [DW-1:0] DecodeErrRespData = 32'hdeadda7a
)(
  input logic                                clk_i,
  input logic                                rst_ni,
  output static_connection_signals_pad2soc_t static_connection_signals_pad2soc,
  input  static_connection_signals_soc2pad_t static_connection_signals_soc2pad,
  output port_signals_pad2soc_t              port_signals_pad2soc,
  input port_signals_soc2pad_t               port_signals_soc2pad,
  // Landing Pads
  inout wire logic                           pad_periph_ref_clk_pad,
  inout wire logic                           pad_periph_fll_host_pad,
  inout wire logic                           pad_periph_fll_periph_pad,
  inout wire logic                           pad_periph_fll_alt_pad,
  inout wire logic                           pad_periph_fll_rt_pad,
  inout wire logic                           pad_periph_fll_bypass_pad,
  inout wire logic                           pad_periph_pwr_on_rst_n_pad,
  inout wire logic                           pad_periph_secure_boot_pad,
  inout wire logic                           pad_periph_jtag_tclk_pad,
  inout wire logic                           pad_periph_jtag_trst_n_pad,
  inout wire logic                           pad_periph_jtag_tms_pad,
  inout wire logic                           pad_periph_jtag_tdi_pad,
  inout wire logic                           pad_periph_jtag_tdo_pad,
  inout wire logic                           pad_periph_test_mode_pad,
  inout wire logic                           pad_periph_boot_mode_0_pad,
  inout wire logic                           pad_periph_boot_mode_1_pad,
  inout wire logic                           pad_periph_ot_boot_mode_pad,
  inout wire logic                           pad_periph_jtag_ot_tclk_pad,
  inout wire logic                           pad_periph_jtag_ot_trst_ni_pad,
  inout wire logic                           pad_periph_jtag_ot_tms_pad,
  inout wire logic                           pad_periph_jtag_ot_tdi_pad,
  inout wire logic                           pad_periph_jtag_ot_tdo_pad,
  inout wire logic                           pad_periph_hyper_cs_0_n_pad,
  inout wire logic                           pad_periph_hyper_cs_1_n_pad,
  inout wire logic                           pad_periph_hyper_ck_pad,
  inout wire logic                           pad_periph_hyper_ck_n_pad,
  inout wire logic                           pad_periph_hyper_rwds_pad,
  inout wire logic                           pad_periph_hyper_dq_0_pad,
  inout wire logic                           pad_periph_hyper_dq_1_pad,
  inout wire logic                           pad_periph_hyper_dq_2_pad,
  inout wire logic                           pad_periph_hyper_dq_3_pad,
  inout wire logic                           pad_periph_hyper_dq_4_pad,
  inout wire logic                           pad_periph_hyper_dq_5_pad,
  inout wire logic                           pad_periph_hyper_dq_6_pad,
  inout wire logic                           pad_periph_hyper_dq_7_pad,
  inout wire logic                           pad_periph_hyper_reset_n_pad,
  inout wire logic                           pad_periph_spw_data_in_pad,
  inout wire logic                           pad_periph_spw_strb_in_pad,
  inout wire logic                           pad_periph_spw_data_out_pad,
  inout wire logic                           pad_periph_spw_strb_out_pad,
  inout wire logic                           pad_periph_uart_tx_out_pad,
  inout wire logic                           pad_periph_uart_rx_in_pad,
  inout wire logic                           pad_periph_muxed_v_00_pad,
  inout wire logic                           pad_periph_muxed_v_01_pad,
  inout wire logic                           pad_periph_muxed_v_02_pad,
  inout wire logic                           pad_periph_muxed_v_03_pad,
  inout wire logic                           pad_periph_muxed_v_04_pad,
  inout wire logic                           pad_periph_muxed_v_05_pad,
  inout wire logic                           pad_periph_muxed_v_06_pad,
  inout wire logic                           pad_periph_muxed_v_07_pad,
  inout wire logic                           pad_periph_muxed_v_08_pad,
  inout wire logic                           pad_periph_muxed_v_09_pad,
  inout wire logic                           pad_periph_muxed_v_10_pad,
  inout wire logic                           pad_periph_muxed_v_11_pad,
  inout wire logic                           pad_periph_muxed_v_12_pad,
  inout wire logic                           pad_periph_muxed_v_13_pad,
  inout wire logic                           pad_periph_muxed_v_14_pad,
  inout wire logic                           pad_periph_muxed_v_15_pad,
  inout wire logic                           pad_periph_muxed_v_16_pad,
  inout wire logic                           pad_periph_muxed_v_17_pad,
  inout wire logic                           pad_periph_muxed_h_00_pad,
  inout wire logic                           pad_periph_muxed_h_01_pad,
  inout wire logic                           pad_periph_muxed_h_02_pad,
  inout wire logic                           pad_periph_muxed_h_03_pad,
  // Config Interface
  input req_t                                config_req_i,
  output resp_t                              config_rsp_o
  );


  req_t periph_config_req;
  resp_t periph_config_resp;
  astral_padframe_periph #(
    .req_t(req_t),
    .resp_t(resp_t)
  ) i_periph (
   .clk_i,
   .rst_ni,
   .static_connection_signals_pad2soc(static_connection_signals_pad2soc.periph),
   .static_connection_signals_soc2pad(static_connection_signals_soc2pad.periph),
   .port_signals_pad2soc_o(port_signals_pad2soc.periph),
   .port_signals_soc2pad_i(port_signals_soc2pad.periph),
   .pad_ref_clk_pad(pad_periph_ref_clk_pad),
   .pad_fll_host_pad(pad_periph_fll_host_pad),
   .pad_fll_periph_pad(pad_periph_fll_periph_pad),
   .pad_fll_alt_pad(pad_periph_fll_alt_pad),
   .pad_fll_rt_pad(pad_periph_fll_rt_pad),
   .pad_fll_bypass_pad(pad_periph_fll_bypass_pad),
   .pad_pwr_on_rst_n_pad(pad_periph_pwr_on_rst_n_pad),
   .pad_secure_boot_pad(pad_periph_secure_boot_pad),
   .pad_jtag_tclk_pad(pad_periph_jtag_tclk_pad),
   .pad_jtag_trst_n_pad(pad_periph_jtag_trst_n_pad),
   .pad_jtag_tms_pad(pad_periph_jtag_tms_pad),
   .pad_jtag_tdi_pad(pad_periph_jtag_tdi_pad),
   .pad_jtag_tdo_pad(pad_periph_jtag_tdo_pad),
   .pad_test_mode_pad(pad_periph_test_mode_pad),
   .pad_boot_mode_0_pad(pad_periph_boot_mode_0_pad),
   .pad_boot_mode_1_pad(pad_periph_boot_mode_1_pad),
   .pad_ot_boot_mode_pad(pad_periph_ot_boot_mode_pad),
   .pad_jtag_ot_tclk_pad(pad_periph_jtag_ot_tclk_pad),
   .pad_jtag_ot_trst_ni_pad(pad_periph_jtag_ot_trst_ni_pad),
   .pad_jtag_ot_tms_pad(pad_periph_jtag_ot_tms_pad),
   .pad_jtag_ot_tdi_pad(pad_periph_jtag_ot_tdi_pad),
   .pad_jtag_ot_tdo_pad(pad_periph_jtag_ot_tdo_pad),
   .pad_hyper_cs_0_n_pad(pad_periph_hyper_cs_0_n_pad),
   .pad_hyper_cs_1_n_pad(pad_periph_hyper_cs_1_n_pad),
   .pad_hyper_ck_pad(pad_periph_hyper_ck_pad),
   .pad_hyper_ck_n_pad(pad_periph_hyper_ck_n_pad),
   .pad_hyper_rwds_pad(pad_periph_hyper_rwds_pad),
   .pad_hyper_dq_0_pad(pad_periph_hyper_dq_0_pad),
   .pad_hyper_dq_1_pad(pad_periph_hyper_dq_1_pad),
   .pad_hyper_dq_2_pad(pad_periph_hyper_dq_2_pad),
   .pad_hyper_dq_3_pad(pad_periph_hyper_dq_3_pad),
   .pad_hyper_dq_4_pad(pad_periph_hyper_dq_4_pad),
   .pad_hyper_dq_5_pad(pad_periph_hyper_dq_5_pad),
   .pad_hyper_dq_6_pad(pad_periph_hyper_dq_6_pad),
   .pad_hyper_dq_7_pad(pad_periph_hyper_dq_7_pad),
   .pad_hyper_reset_n_pad(pad_periph_hyper_reset_n_pad),
   .pad_spw_data_in_pad(pad_periph_spw_data_in_pad),
   .pad_spw_strb_in_pad(pad_periph_spw_strb_in_pad),
   .pad_spw_data_out_pad(pad_periph_spw_data_out_pad),
   .pad_spw_strb_out_pad(pad_periph_spw_strb_out_pad),
   .pad_uart_tx_out_pad(pad_periph_uart_tx_out_pad),
   .pad_uart_rx_in_pad(pad_periph_uart_rx_in_pad),
   .pad_muxed_v_00_pad(pad_periph_muxed_v_00_pad),
   .pad_muxed_v_01_pad(pad_periph_muxed_v_01_pad),
   .pad_muxed_v_02_pad(pad_periph_muxed_v_02_pad),
   .pad_muxed_v_03_pad(pad_periph_muxed_v_03_pad),
   .pad_muxed_v_04_pad(pad_periph_muxed_v_04_pad),
   .pad_muxed_v_05_pad(pad_periph_muxed_v_05_pad),
   .pad_muxed_v_06_pad(pad_periph_muxed_v_06_pad),
   .pad_muxed_v_07_pad(pad_periph_muxed_v_07_pad),
   .pad_muxed_v_08_pad(pad_periph_muxed_v_08_pad),
   .pad_muxed_v_09_pad(pad_periph_muxed_v_09_pad),
   .pad_muxed_v_10_pad(pad_periph_muxed_v_10_pad),
   .pad_muxed_v_11_pad(pad_periph_muxed_v_11_pad),
   .pad_muxed_v_12_pad(pad_periph_muxed_v_12_pad),
   .pad_muxed_v_13_pad(pad_periph_muxed_v_13_pad),
   .pad_muxed_v_14_pad(pad_periph_muxed_v_14_pad),
   .pad_muxed_v_15_pad(pad_periph_muxed_v_15_pad),
   .pad_muxed_v_16_pad(pad_periph_muxed_v_16_pad),
   .pad_muxed_v_17_pad(pad_periph_muxed_v_17_pad),
   .pad_muxed_h_00_pad(pad_periph_muxed_h_00_pad),
   .pad_muxed_h_01_pad(pad_periph_muxed_h_01_pad),
   .pad_muxed_h_02_pad(pad_periph_muxed_h_02_pad),
   .pad_muxed_h_03_pad(pad_periph_muxed_h_03_pad),
   .config_req_i(periph_config_req),
   .config_rsp_o(periph_config_resp)
  );


   localparam int unsigned NUM_PAD_DOMAINS = 1;
   localparam int unsigned REG_ADDR_WIDTH = 8;
   typedef struct packed {
      int unsigned idx;
      logic [REG_ADDR_WIDTH-1:0] start_addr;
      logic [REG_ADDR_WIDTH-1:0] end_addr;
   } addr_rule_t;

   localparam addr_rule_t[NUM_PAD_DOMAINS-1:0] ADDR_DEMUX_RULES = '{
     '{ idx: 0, start_addr: 8'd0,  end_addr: 8'd180}
     };
   logic[$clog2(NUM_PAD_DOMAINS+1)-1:0] pad_domain_sel; // +1 since there is an additional error slave
   addr_decode #(
       .NoIndices(NUM_PAD_DOMAINS+1),
       .NoRules(NUM_PAD_DOMAINS),
       .addr_t(logic[REG_ADDR_WIDTH-1:0]),
       .rule_t(addr_rule_t)
     ) i_addr_decode(
       .addr_i(config_req_i.addr[REG_ADDR_WIDTH-1:0]),
       .addr_map_i(ADDR_DEMUX_RULES),
       .dec_valid_o(),
       .dec_error_o(),
       .idx_o(pad_domain_sel),
       .en_default_idx_i(1'b1),
       .default_idx_i(1'd1) // The last entry is the error slave
     );

     req_t error_slave_req;
     resp_t error_slave_rsp;

     // Config Interface demultiplexing
     reg_demux #(
       .NoPorts(NUM_PAD_DOMAINS+1), //+1 for the error slave
       .req_t(req_t),
       .rsp_t(resp_t)
     ) i_config_demuxer (
       .clk_i,
       .rst_ni,
       .in_select_i(pad_domain_sel),
       .in_req_i(config_req_i),
       .in_rsp_o(config_rsp_o),
       .out_req_o({error_slave_req, periph_config_req}),
       .out_rsp_i({error_slave_rsp, periph_config_resp})
     );

     assign error_slave_rsp.error = 1'b1;
     assign error_slave_rsp.rdata = DecodeErrRespData;
     assign error_slave_rsp.ready = 1'b1;

endmodule
