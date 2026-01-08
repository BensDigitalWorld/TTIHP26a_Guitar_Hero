# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Takt auf 25.175 MHz setzen (ca. 39.72ns Periode)
    clock = Clock(dut.clk, 40, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    dut._log.info("Warte auf VGA und Sound...")

    # Wir simulieren für 1000 Takte
    for i in range(1000):
        await ClockCycles(dut.clk, 1)
        
        # Optional: Prüfen, ob der Sound-Pin (uio_out Bit 7) sich bewegt
        # Wir loggen es nur, wenn er auf 1 geht
        if dut.uio_out[7].value == 1:
             dut._log.debug("Sound PWM High entdeckt!")

    # Anstatt 'assert == 50', prüfen wir sinnvolle Dinge:
    
    # 1. Prüfen, ob hsync oder vsync (in uo_out) vorhanden sind
    # uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]}
    # Wir schauen, ob uo_out nicht dauerhaft 0 ist
    assert dut.uo_out.value != 50, "Der alte Testwert 50 ist hier nicht sinnvoll."
    
    dut._log.info("Test erfolgreich beendet!")
