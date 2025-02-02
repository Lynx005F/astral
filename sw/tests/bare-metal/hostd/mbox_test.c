// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Maicol Ciani <maicol.ciani@unibo.it>
//

#include "car_memory_map.h"
#include "io.h"
#include "regs/cheshire.h"
#include "sw/device/lib/dif/dif_rv_plic.h" // to be changed accoridng to correct hash
#include "dif/clint.h"
#include "dif/uart.h"
#include "params.h"
#include "util.h"
#include <stdio.h>
#include <stdlib.h>

static dif_rv_plic_t plic0;

#define IRQID 69 // index of mbox irq in the irq vector input to the PLIC

int main(int argc, char const *argv[]) {

    // Put SMP Hart to sleep
    if (hart_id() != 0) wfi();

    int prio = 0x1;
    int a,b,c,d,e;
    bool t;
    unsigned global_irq_en   = 0x00001808;
    unsigned external_irq_en = 0x00000800;

    // Uart setup
    uint32_t rtc_freq = *reg32(&__base_regs, CHESHIRE_RTC_FREQ_REG_OFFSET);
    uint64_t reset_freq = clint_get_core_freq(rtc_freq, 2500);
    uart_init(&__base_uart, reset_freq, 115200);

    asm volatile("csrw  mstatus, %0\n" : : "r"(global_irq_en  ));     // Set global interrupt enable in CVA6 csr
    asm volatile("csrw  mie, %0\n"     : : "r"(external_irq_en));     // Set external interrupt enable in CVA6 csr
    // PLIC setup
    mmio_region_t plic_base_addr = mmio_region_from_addr(&__base_plic);
    t = dif_rv_plic_init(plic_base_addr, &plic0);
    // Set two consecutive interrupts otherwise the SLINK breaks while loading the binary...
    for (int i = 0; i < 2; i++) {
      t = dif_rv_plic_irq_set_priority(&plic0, IRQID+i*5, prio);
      t = dif_rv_plic_irq_set_enabled(&plic0, IRQID+i*5, 0, kDifToggleEnabled);
    }
    writew(0xBAADC0DE, 0x40000280);
    a = readw(0x40000280);
    if( a == 0xBAADC0DE )
      writew(0x00000001, 0x40000204); // ring doorbell if mailbox is accessible
      writew(0x00000001, 0x4000020C);
    wfi();
    return 0;
}

void trap_vector (void){
   int * claim_irq;
   dif_rv_plic_irq_claim(&plic0, 0, &claim_irq);
   dif_rv_plic_irq_complete(&plic0, 0, &claim_irq);
   writew(0x0, 0x40000D04);
   writew(0x0, 0x40000D0C);
   writew(0x1, 0x40000D08);
   return;
}
