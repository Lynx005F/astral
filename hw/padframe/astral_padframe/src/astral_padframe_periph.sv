
// File auto-generated by Padrick unknown
module astral_padframe_periph
  import pkg_astral_padframe::*;
  import pkg_internal_astral_padframe_periph::*;
#(
  parameter type              req_t  = logic, // reg_interface request type
  parameter type             resp_t  = logic // reg_interface response type
) (
  input logic clk_i,
  input logic rst_ni,
  output pad_domain_periph_static_connection_signals_pad2soc_t static_connection_signals_pad2soc,
  input pad_domain_periph_static_connection_signals_soc2pad_t static_connection_signals_soc2pad,
  output pad_domain_periph_ports_pad2soc_t port_signals_pad2soc_o,
  input pad_domain_periph_ports_soc2pad_t port_signals_soc2pad_i,
  inout wire logic pad_ref_clk_pad_i,
  inout wire logic pad_ref_clk_pad_o,
  inout wire logic pad_fll_host_pad,
  inout wire logic pad_fll_periph_pad,
  inout wire logic pad_fll_alt_pad,
  inout wire logic pad_fll_rt_pad,
  inout wire logic pad_fll_bypass_pad,
  inout wire logic pad_pwr_on_rst_n_pad,
  inout wire logic pad_secure_boot_pad,
  inout wire logic pad_jtag_tclk_pad,
  inout wire logic pad_jtag_trst_n_pad,
  inout wire logic pad_jtag_tms_pad,
  inout wire logic pad_jtag_tdi_pad,
  inout wire logic pad_jtag_tdo_pad,
  inout wire logic pad_test_mode_pad,
  inout wire logic pad_boot_mode_0_pad,
  inout wire logic pad_boot_mode_1_pad,
  inout wire logic pad_jtag_ot_tclk_pad,
  inout wire logic pad_jtag_ot_trst_ni_pad,
  inout wire logic pad_jtag_ot_tms_pad,
  inout wire logic pad_jtag_ot_tdi_pad,
  inout wire logic pad_jtag_ot_tdo_pad,
  inout wire logic pad_hyper_cs_0_n_pad,
  inout wire logic pad_hyper_cs_1_n_pad,
  inout wire logic pad_hyper_ck_pad,
  inout wire logic pad_hyper_ck_n_pad,
  inout wire logic pad_hyper_rwds_pad,
  inout wire logic pad_hyper_dq_0_pad,
  inout wire logic pad_hyper_dq_1_pad,
  inout wire logic pad_hyper_dq_2_pad,
  inout wire logic pad_hyper_dq_3_pad,
  inout wire logic pad_hyper_dq_4_pad,
  inout wire logic pad_hyper_dq_5_pad,
  inout wire logic pad_hyper_dq_6_pad,
  inout wire logic pad_hyper_dq_7_pad,
  inout wire logic pad_hyper_reset_n_pad,
  inout wire logic pad_spw_data_in_pad,
  inout wire logic pad_spw_strb_in_pad,
  inout wire logic pad_spw_data_out_pad,
  inout wire logic pad_spw_strb_out_pad,
  inout wire logic pad_uart_tx_out_pad,
  inout wire logic pad_uart_rx_in_pad,
  inout wire logic pad_muxed_v_00_pad,
  inout wire logic pad_muxed_v_01_pad,
  inout wire logic pad_muxed_v_02_pad,
  inout wire logic pad_muxed_v_03_pad,
  inout wire logic pad_muxed_v_04_pad,
  inout wire logic pad_muxed_v_05_pad,
  inout wire logic pad_muxed_v_06_pad,
  inout wire logic pad_muxed_v_07_pad,
  inout wire logic pad_muxed_v_08_pad,
  inout wire logic pad_muxed_v_09_pad,
  inout wire logic pad_muxed_v_10_pad,
  inout wire logic pad_muxed_v_11_pad,
  inout wire logic pad_muxed_v_12_pad,
  inout wire logic pad_muxed_v_13_pad,
  inout wire logic pad_muxed_v_14_pad,
  inout wire logic pad_muxed_v_15_pad,
  inout wire logic pad_muxed_v_16_pad,
  inout wire logic pad_muxed_v_17_pad,
  inout wire logic pad_muxed_v_18_pad,
  inout wire logic pad_muxed_v_19_pad,
  inout wire logic pad_muxed_v_20_pad,
  inout wire logic pad_muxed_v_21_pad,
  input req_t config_req_i,
  output resp_t config_rsp_o
);

   mux_to_pads_t s_mux_to_pads;
   pads_to_mux_t s_pads_to_mux;

   astral_padframe_periph_pads i_periph_pads (
     .static_connection_signals_pad2soc,
     .static_connection_signals_soc2pad,
     .mux_to_pads_i(s_mux_to_pads),
     .pads_to_mux_o(s_pads_to_mux),
     .pad_ref_clk_pad_i,
     .pad_ref_clk_pad_o,
     .pad_fll_host_pad,
     .pad_fll_periph_pad,
     .pad_fll_alt_pad,
     .pad_fll_rt_pad,
     .pad_fll_bypass_pad,
     .pad_pwr_on_rst_n_pad,
     .pad_secure_boot_pad,
     .pad_jtag_tclk_pad,
     .pad_jtag_trst_n_pad,
     .pad_jtag_tms_pad,
     .pad_jtag_tdi_pad,
     .pad_jtag_tdo_pad,
     .pad_test_mode_pad,
     .pad_boot_mode_0_pad,
     .pad_boot_mode_1_pad,
     .pad_jtag_ot_tclk_pad,
     .pad_jtag_ot_trst_ni_pad,
     .pad_jtag_ot_tms_pad,
     .pad_jtag_ot_tdi_pad,
     .pad_jtag_ot_tdo_pad,
     .pad_hyper_cs_0_n_pad,
     .pad_hyper_cs_1_n_pad,
     .pad_hyper_ck_pad,
     .pad_hyper_ck_n_pad,
     .pad_hyper_rwds_pad,
     .pad_hyper_dq_0_pad,
     .pad_hyper_dq_1_pad,
     .pad_hyper_dq_2_pad,
     .pad_hyper_dq_3_pad,
     .pad_hyper_dq_4_pad,
     .pad_hyper_dq_5_pad,
     .pad_hyper_dq_6_pad,
     .pad_hyper_dq_7_pad,
     .pad_hyper_reset_n_pad,
     .pad_spw_data_in_pad,
     .pad_spw_strb_in_pad,
     .pad_spw_data_out_pad,
     .pad_spw_strb_out_pad,
     .pad_uart_tx_out_pad,
     .pad_uart_rx_in_pad,
     .pad_muxed_v_00_pad,
     .pad_muxed_v_01_pad,
     .pad_muxed_v_02_pad,
     .pad_muxed_v_03_pad,
     .pad_muxed_v_04_pad,
     .pad_muxed_v_05_pad,
     .pad_muxed_v_06_pad,
     .pad_muxed_v_07_pad,
     .pad_muxed_v_08_pad,
     .pad_muxed_v_09_pad,
     .pad_muxed_v_10_pad,
     .pad_muxed_v_11_pad,
     .pad_muxed_v_12_pad,
     .pad_muxed_v_13_pad,
     .pad_muxed_v_14_pad,
     .pad_muxed_v_15_pad,
     .pad_muxed_v_16_pad,
     .pad_muxed_v_17_pad,
     .pad_muxed_v_18_pad,
     .pad_muxed_v_19_pad,
     .pad_muxed_v_20_pad,
     .pad_muxed_v_21_pad

  );

   astral_padframe_periph_muxer #(
     .req_t(req_t),
     .resp_t(resp_t)
   )i_periph_muxer (
     .clk_i,
     .rst_ni,
     .port_signals_soc2pad_i,
     .port_signals_pad2soc_o,
     .mux_to_pads_o(s_mux_to_pads),
     .pads_to_mux_i(s_pads_to_mux),
     // Configuration interface using register_interface protocol
     .config_req_i,
     .config_rsp_o
   );

endmodule : astral_padframe_periph
