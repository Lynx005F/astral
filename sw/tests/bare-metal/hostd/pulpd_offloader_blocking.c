// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Yvan Tortorella <yvan.tortorella@unibo.it>
//
// Bare-metal offload test for the PULP cluster

#include <stdio.h>
#include <stdint.h>

#include "car_memory_map.h"
#include "car_util.h"
#include "dif/clint.h"
#include "dif/uart.h"
#include "params.h"
#include "regs/cheshire.h"
#include "util.h"
#include "payload.h"

int main(void)
{

  // Put SMP Hart to sleep
  if (hart_id() != 0) wfi();

  // Init the HW
  // PULP Island
  car_enable_domain(CAR_PULP_RST);

  char str[] = "Cluster boot.\r\n";
  uint32_t rtc_freq = *reg32(&__base_regs, CHESHIRE_RTC_FREQ_REG_OFFSET);
  uint64_t reset_freq = clint_get_core_freq(rtc_freq, 2500);

  load_binary();

  // The `load_binary()` function is usually loading the L2 or LLC with the
  // cluster code. Both L2 and LLC are in the cachable region, and since we
  // use WB caches we need to flush them to commit the content to the target
  // memories.
  fencei();

  volatile uint32_t pulp_boot_default = ELF_BOOT_ADDR;
  volatile uint32_t pulp_ret_val = 0;

  pulp_cluster_set_bootaddress(pulp_boot_default);

  uart_init(&__base_uart, reset_freq, 115200);
  uart_write_str(&__base_uart, str, sizeof(str));
  uart_write_flush(&__base_uart);

  pulp_cluster_start();

  pulp_cluster_wait_eoc();

  pulp_ret_val = pulp_cluster_get_return();

  return pulp_ret_val;

}
