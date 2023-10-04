// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Nicole Narr <narrn@student.ethz.ch>
// Christopher Reinwardt <creinwar@student.ethz.ch>
// Paul Scheffler <paulsc@iis.ee.ethz.ch>
// Alessandro Ottaviano <aottaviano@iis.ee.ethz.ch>
// Maicol Ciani <maicol.ciano@unibo.it>

// The security island is inaccessible from other parts of the SoC, hence we
// need to preload it from the testbench. This testbench checks the
// mailbox-based communication between the security_island and other subsystems.

module tb_carfield_soc;

  import uvm_pkg::*;
  import carfield_pkg::*;
  import cheshire_pkg::*;

  // carfield top
  carfield_soc_fixture fix();

  // cheshire
  string      chs_preload_elf;
  string      chs_boot_hex;
  logic [1:0] boot_mode;
  logic [1:0] preload_mode;
  bit [31:0]  exit_code;
  bit         is_dram;

  // safety island
  string      safed_preload_elf;
  logic       safed_boot_mode;
  bit  [31:0] safed_exit_code;
  bit         safed_exit_status;
  bit  [31:0] safed_isolated;

  localparam int unsigned SafetyIslandClkEnRegAddr         = 32'h20010070;
  localparam int unsigned SafetyIslandIsolateRegAddr       = 32'h20010040;
  localparam int unsigned SafetyIslandIsolateStatusRegAddr = 32'h20010058;

  // security island
  string      secd_preload_elf;
  string      secd_flash_vmem;
  logic       secd_boot_mode;

  // hyperbus
  localparam int unsigned HyperbusTburstMax = 32'h20009008;

  //FP Spatz Cluster
  string      spatzd_preload_elf;
  logic [1:0] spatzd_boot_mode;
  bit  [31:0] spatzd_exit_code;
  bit         spatzd_exit_status;
  doub_bt     spatzd_binary_entry;
  doub_bt     spatzd_reg_value;

  //MailBox
  parameter logic [31:0] CAR_MBOX_BASE             = 32'h40000000;
  parameter logic [31:0] CAR_NUM_MAILBOXES         = 32'h25;
  parameter logic [31:0] MBOX_INT_SND_STAT_OFFSET  = 32'h00;
  parameter logic [31:0] MBOX_INT_SND_SET_OFFSET   = 32'h04;
  parameter logic [31:0] MBOX_INT_SND_CLR_OFFSET   = 32'h08;
  parameter logic [31:0] MBOX_INT_SND_EN_OFFSET    = 32'h0C;
  parameter logic [31:0] MBOX_INT_RCV_STAT_OFFSET  = 32'h40;
  parameter logic [31:0] MBOX_INT_RCV_SET_OFFSET   = 32'h44;
  parameter logic [31:0] MBOX_INT_RCV_CLR_OFFSET   = 32'h48;
  parameter logic [31:0] MBOX_INT_RCV_EN_OFFSET    = 32'h4C;
  parameter logic [31:0] MBOX_LETTER0_OFFSET       = 32'h80;
  parameter logic [31:0] MBOX_LETTER1_OFFSET       = 32'h84;

  parameter logic [31:0] MBOX_SPATZ_CORE0_ID = 32'h0;
  parameter logic [31:0] MBOX_SPATZ_CORE1_ID = 32'h1;

  logic [63:0] unused;

  logic        secure_boot;

  // timing format for $display("...$t..", $realtime)
  initial begin : timing_format
    $timeformat(-9, 0, "ns", 9);
  end : timing_format

  // Cheshire standalone binary execution
  initial begin
    // Fetch plusargs or use safe (fail-fast) defaults
    if (!$value$plusargs("SECURE_BOOT=%d",  secure_boot))     secure_boot     = 0;
    if (!$value$plusargs("CHS_BOOTMODE=%d", boot_mode))       boot_mode       = 0;
    if (!$value$plusargs("CHS_PRELMODE=%d", preload_mode))    preload_mode    = 0;
    if (!$value$plusargs("CHS_BINARY=%s",   chs_preload_elf)) chs_preload_elf = "";
    if (!$value$plusargs("CHS_IMAGE=%s",    chs_boot_hex))    chs_boot_hex    = "";

    // Set boot mode and preload boot image if there is one
    fix.set_secure_boot(secure_boot);
    fix.chs_vip.set_boot_mode(boot_mode);
    fix.chs_vip.i2c_eeprom_preload(chs_boot_hex);
    fix.chs_vip.spih_norflash_preload(chs_boot_hex);

    // Wait for reset
    fix.chs_vip.wait_for_reset();

    // Writing max burst length in Hyperbus configuration registers to
    // prevent the Verification IPs from triggering timing checks.
    $display("[TB] INFO: Configuring Hyperbus through serial link.");
    fix.chs_vip.slink_write_32(HyperbusTburstMax, 32'd128);

    if (chs_preload_elf != "" || chs_boot_hex != "") begin
      // When Cheshire is offloading to safety island, the latter should be set in passive preloaded
      // bootmode
      fix.safed_vip.set_safed_boot_mode(safety_island_pkg::Preloaded);
      // Preload in idle mode or wait for completion in autonomous boot
      if (boot_mode == 0) begin
        // Idle boot: preload with the specified mode
        case (preload_mode)
          0: begin // Standalone JTAG passive preload
            // Cheshire
            is_dram = uvm_re_match("dram",chs_preload_elf);
            if(~is_dram) begin
              $display("[TB] %t - Wait for HyperRAM", $realtime);
              repeat(120000)
                @(posedge fix.clk);
            end
            fix.chs_vip.jtag_init();
            fix.chs_vip.jtag_elf_run(chs_preload_elf);
            fix.chs_vip.jtag_wait_for_eoc(exit_code);
          end 1: begin  // Standalone Serial Link passive preload
            // Cheshire
            fix.chs_vip.slink_elf_run(chs_preload_elf);
            fix.chs_vip.slink_wait_for_eoc(exit_code);
          end 2: begin // Standalone UART passive preload
            fix.chs_vip.uart_debug_elf_run_and_wait(chs_preload_elf, exit_code);
          end 3: begin  // Secure boot: Opentitan booting CVA6
            fix.chs_vip.slink_elf_preload(chs_preload_elf, unused);
            fix.chs_vip.jtag_init();
            fix.chs_vip.jtag_wait_for_eoc(exit_code);
          end default: begin
            $fatal(1, "Unsupported preload mode %d (reserved)!", boot_mode);
          end
        endcase
      end else if (boot_mode == 1) begin
        $fatal(1, "Unsupported boot mode %d (SD Card)!", boot_mode);
      end else begin
        // Autonomous boot: Only poll return code
        fix.chs_vip.jtag_init();
        fix.chs_vip.jtag_wait_for_eoc(exit_code);
      end

      // Eventually wait for HWRoT to end initialization anda ssert Ibex's fetch enable
      fix.passthrough_or_wait_for_secd_hw_init();

      // Wait for the UART to finish reading the current byte
      wait (fix.chs_vip.uart_reading_byte == 0);

      $finish;
    end
  end

  // safety island standalone
  initial begin
    // Fetch plusargs or use safe (fail-fast) defaults
    if (!$value$plusargs("SECURE_BOOT=%d",    secure_boot))       secure_boot      = 0;
    if (!$value$plusargs("SAFED_BOOTMODE=%d", safed_boot_mode))   safed_boot_mode   = 0;
    if (!$value$plusargs("SAFED_BINARY=%s",   safed_preload_elf)) safed_preload_elf = "";

    // set secure boot mode
    fix.set_secure_boot(secure_boot);

    if (safed_preload_elf != "") begin

      // set boot mode before reset
      case (safed_boot_mode)
        0: begin
          fix.safed_vip.set_safed_boot_mode(safety_island_pkg::Jtag);
        end 1: begin
          fix.safed_vip.set_safed_boot_mode(safety_island_pkg::Preloaded);
       end default: begin
          $fatal(1, "Unsupported boot mode %d (reserved)!", safed_boot_mode);
        end
      endcase

      fix.safed_vip.safed_wait_for_reset();

      $display("[TB] %t - Enabling safety island clock for stand-alone tests ", $realtime);
      // Clock island after PoR
      fix.safed_vip.axi_write_32(SafetyIslandClkEnRegAddr, 32'h1);
      $display("[TB] %t - De-isolate safety island for stand-alone tests ", $realtime);
      // De-isolate island after PoR
      fix.safed_vip.axi_write_32(SafetyIslandIsolateRegAddr, 32'h0);

      case (safed_boot_mode)
        0: begin
          fix.safed_vip.jtag_safed_init();
          fix.safed_vip.jtag_write_test(32'h6000_1000, 32'hABBA_ABBA);
          fix.safed_vip.jtag_safed_elf_run(safed_preload_elf);
          fix.safed_vip.jtag_safed_wait_for_eoc(safed_exit_code, safed_exit_status);
        end 1: begin
          fix.safed_vip.axi_safed_elf_run(safed_preload_elf);
          fix.safed_vip.axi_safed_wait_for_eoc(safed_exit_code, safed_exit_status);
       end default: begin
          $fatal(1, "Unsupported boot mode %d (reserved)!", safed_boot_mode);
        end
      endcase

      $finish;
    end
  end

  // security island standalone
  initial begin
    // Fetch plusargs or use safe (fail-fast) defaults
    if (!$value$plusargs("SECURE_BOOT=%d",   secure_boot))      secure_boot      = 0;
    if (!$value$plusargs("SECD_FLASH=%s",    secd_flash_vmem))  secd_flash_vmem  = "";
    if (!$value$plusargs("SECD_BINARY=%s",   secd_preload_elf)) secd_preload_elf = "";
    if (!$value$plusargs("SECD_BOOTMODE=%d", secd_boot_mode))   secd_boot_mode   = 0;
    case(secd_boot_mode)
      0: begin
        // Go in secure bootmode to let the Security island be de-isolated and clocked after PoR
        $display("[TB] %t - Entering secure boot mode for Security island after PoR (clock enable and de-isolation handled in HW)", $realtime);
        fix.set_secure_boot(secure_boot);
        fix.secd_vip.set_secd_boot_mode(2'b00);
        if (secd_preload_elf != "") begin
          // Wait before security island HW is initialized
          repeat(10000)
            @(posedge fix.clk);
          fix.secd_vip.debug_secd_module_init();
          fix.secd_vip.load_secd_binary(secd_preload_elf);
          fix.secd_vip.jtag_secd_data_preload();
          fix.secd_vip.jtag_secd_wakeup(32'hE0000080);
          fix.secd_vip.jtag_secd_wait_eoc();
        end
      end 1: begin
        // Go in secure bootmode to let the Security island be de-isolated and clocked after PoR
        $display("[TB] %t - Entering secure boot mode for Security island after PoR (clock enable and de-isolation handled in HW)", $realtime);
        fix.set_secure_boot(secure_boot);
        fix.secd_vip.set_secd_boot_mode(2'b01);
        fix.secd_vip.spih_norflash_preload(secd_flash_vmem);
        repeat(10000)
            @(posedge fix.clk);
        fix.secd_vip.jtag_secd_wait_eoc();
      end default: begin
        $fatal(1, "Unsupported boot mode %d (reserved)!", safed_boot_mode);
      end
    endcase
  end

  // pulp cluster standalone
  // TODO

  // spatz cluster standalone
  initial begin
    // Fetch plusargs or use safe (fail-fast) defaults
    if (!$value$plusargs("SPATZD_BOOTMODE=%d",     spatzd_boot_mode))   spatzd_boot_mode   = 0;
    if (!$value$plusargs("SPATZD_BINARY=%s",       spatzd_preload_elf)) spatzd_preload_elf = "";

    // Wait for reset
    fix.chs_vip.wait_for_reset();

    if (spatzd_preload_elf != "") begin
      case (spatzd_boot_mode)
        0: begin
          // JTAG
          $display("[JTAG SPATZD] Init ");
          fix.chs_vip.jtag_init();
          $display("[JTAG SPATZD] Halt the core and load the binary to L2 ");
          fix.chs_vip.jtag_elf_halt_load(spatzd_preload_elf, spatzd_binary_entry );

          // write start address into the csr
          $display("[JTAG SPATZD] write the CSR %x of spatz with the entry point %x", spatz_cluster_pkg::PeriStartAddr + spatz_cluster_peripheral_reg_pkg::SPATZ_CLUSTER_PERIPHERAL_CLUSTER_BOOT_CONTROL_OFFSET, spatzd_binary_entry);
          fix.chs_vip.jtag_write_reg(spatz_cluster_pkg::PeriStartAddr + spatz_cluster_peripheral_reg_pkg::SPATZ_CLUSTER_PERIPHERAL_CLUSTER_BOOT_CONTROL_OFFSET, spatzd_binary_entry );

          // Set interrupt on mailbox mailbox id MBOX_SPATZD_CORE0_ID and MBOX_SPATZD_CORE1_ID
          spatzd_reg_value = 64'h1;
          $display("[JTAG SPATZD] Set mailbox interrupt ID  %x at %x ",MBOX_SPATZ_CORE0_ID, CAR_MBOX_BASE +  MBOX_INT_SND_SET_OFFSET + (MBOX_SPATZ_CORE0_ID*32'h100));
          fix.chs_vip.jtag_write_reg32(CAR_MBOX_BASE +  MBOX_INT_SND_SET_OFFSET + (MBOX_SPATZ_CORE0_ID*32'h100) , spatzd_reg_value);

          $display("[JTAG SPATZD] Set mailbox interrupt ID  %x at %x ",MBOX_SPATZ_CORE1_ID, CAR_MBOX_BASE +  MBOX_INT_SND_SET_OFFSET + (MBOX_SPATZ_CORE1_ID*32'h100));
          fix.chs_vip.jtag_write_reg32(CAR_MBOX_BASE +  MBOX_INT_SND_SET_OFFSET + (MBOX_SPATZ_CORE1_ID*32'h100) , spatzd_reg_value);

          // Enable interrupt on mailbox id MBOX_SPATZ_CORE0_ID and MBOX_SPATZ_CORE1_ID
          $display("[JTAG SPATZD] Enable mailbox interrupt ID  %x at %x ",MBOX_SPATZ_CORE0_ID, CAR_MBOX_BASE +  MBOX_INT_SND_EN_OFFSET + (MBOX_SPATZ_CORE0_ID*32'h100) ,spatzd_reg_value);
          fix.chs_vip.jtag_write_reg32(CAR_MBOX_BASE +  MBOX_INT_SND_EN_OFFSET + (MBOX_SPATZ_CORE0_ID*32'h100) , spatzd_reg_value);

          $display("[JTAG SPATZD] Enable mailbox interrupt ID  %x at %x ",MBOX_SPATZ_CORE1_ID, CAR_MBOX_BASE +  MBOX_INT_SND_EN_OFFSET + (MBOX_SPATZ_CORE1_ID*32'h100) ,spatzd_reg_value);
          fix.chs_vip.jtag_write_reg32(CAR_MBOX_BASE +  MBOX_INT_SND_EN_OFFSET + (MBOX_SPATZ_CORE1_ID*32'h100) , spatzd_reg_value);

          // Poll memory address for Spatz EOC
          fix.chs_vip.jtag_poll_bit0(spatz_cluster_pkg::PeriStartAddr + spatz_cluster_peripheral_reg_pkg::SPATZ_CLUSTER_PERIPHERAL_CLUSTER_EOC_EXIT_OFFSET, spatzd_exit_code, 20);
          spatzd_exit_code >>= 1;
          if (spatzd_exit_code) $error("[JTAG SPATZ] FAILED: return code %0d", spatzd_exit_code);
          else $display("[JTAG SPATZD] SUCCESS");
        end

        1: begin
          // SERIAL LINK
          $display("[SLINK SPATZD] Preload the binary to L2 ");
          fix.chs_vip.slink_elf_preload(spatzd_preload_elf, spatzd_binary_entry);

          // write start address into the csr
          $display("[SLINK SPATZD] Write the CSR %x of spatz with the entry point %x", spatz_cluster_pkg::PeriStartAddr + spatz_cluster_peripheral_reg_pkg::SPATZ_CLUSTER_PERIPHERAL_CLUSTER_BOOT_CONTROL_OFFSET, spatzd_binary_entry);
          fix.chs_vip.slink_write_32(spatz_cluster_pkg::PeriStartAddr + spatz_cluster_peripheral_reg_pkg::SPATZ_CLUSTER_PERIPHERAL_CLUSTER_BOOT_CONTROL_OFFSET, spatzd_binary_entry);

          // Set interrupt on mailbox mailbox id MBOX_SPATZ_CORE0_ID and MBOX_SPATZ_CORE1_ID
          spatzd_reg_value = 64'h1;
          $display("[SLINK SPATZD] Set mailbox interrupt ID  %x at %x ",MBOX_SPATZ_CORE0_ID, CAR_MBOX_BASE +  MBOX_INT_SND_SET_OFFSET + (MBOX_SPATZ_CORE0_ID*32'h100));
          fix.chs_vip.slink_write_32(CAR_MBOX_BASE +  MBOX_INT_SND_SET_OFFSET + (MBOX_SPATZ_CORE0_ID*32'h100) , spatzd_reg_value);

          $display("[SLINK SPATZD] Set mailbox interrupt ID  %x at %x ",MBOX_SPATZ_CORE0_ID, CAR_MBOX_BASE +  MBOX_INT_SND_SET_OFFSET + (MBOX_SPATZ_CORE1_ID*32'h100));
          fix.chs_vip.slink_write_32(CAR_MBOX_BASE +  MBOX_INT_SND_SET_OFFSET + (MBOX_SPATZ_CORE1_ID*32'h100) , spatzd_reg_value);

          // Enable interrupt on mailbox id MBOX_SPATZ_CORE0_ID and MBOX_SPATZ_CORE1_ID
          $display("[SLINK SPATZD] Enable mailbox interrupt ID  %x at %x ",MBOX_SPATZ_CORE0_ID, CAR_MBOX_BASE +  MBOX_INT_SND_EN_OFFSET + (MBOX_SPATZ_CORE0_ID*32'h100) ,spatzd_reg_value);
          fix.chs_vip.slink_write_32(CAR_MBOX_BASE +  MBOX_INT_SND_EN_OFFSET + (MBOX_SPATZ_CORE0_ID*32'h100) , spatzd_reg_value);

          $display("[SLINK SPATZD] Enable mailbox interrupt ID  %x at %x ",MBOX_SPATZ_CORE0_ID, CAR_MBOX_BASE +  MBOX_INT_SND_EN_OFFSET + (MBOX_SPATZ_CORE1_ID*32'h100) ,spatzd_reg_value);
          fix.chs_vip.slink_write_32(CAR_MBOX_BASE +  MBOX_INT_SND_EN_OFFSET + (MBOX_SPATZ_CORE1_ID*32'h100) , spatzd_reg_value);

          // Poll memory address for Spatz EOC
          fix.chs_vip.slink_poll_bit0(spatz_cluster_pkg::PeriStartAddr + spatz_cluster_peripheral_reg_pkg::SPATZ_CLUSTER_PERIPHERAL_CLUSTER_EOC_EXIT_OFFSET, spatzd_exit_code, 20);
          spatzd_exit_code >>= 1;
          if (spatzd_exit_code) $error("[JTAG SPATZ] FAILED: return code %0d", spatzd_exit_code);
          else $display("[JTAG SPATZ] SUCCESS");
        end

        default: begin
          $fatal(1, "Unsupported boot mode %d (reserved)!", spatzd_boot_mode);
        end
      endcase
      $finish;
    end
  end

endmodule
