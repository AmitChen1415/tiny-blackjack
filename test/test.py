# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge
import os

# -----------------------------------------------------------------------------
# UI bit mapping (from your TOP)
# ui_in[0] = HIT
# ui_in[1] = STAND
# ui_in[2] = DOUBLE
# ui_in[4] = START
# -----------------------------------------------------------------------------
BTN_HIT    = 1 << 0
BTN_STAND  = 1 << 1
BTN_DOUBLE = 1 << 2
BTN_START  = 1 << 4
NOT_PUSHED = 0


class GameDriver:
    """
    Blackjack Game Driver for TinyTapeout TOP (tt_um_AmitChen1415)

    - Drives user inputs on ui_in (start/hit/stand/double)
    - Manages reset/clock
    - Provides convenience reads of internal debug signals when hierarchy is visible:
        game_inst.dbg_deal_count
        game_inst.dbg_last_card
        game_inst.dbg_blackjack
        game_inst.user_total
        game_inst.dealer_total
        game_inst.balance
      These are optional; tests still work without them (methods will fallback).
    """

    def __init__(self, dut, clk_period_ns=40):
        self._dut = dut
        # start clock
        clock = Clock(dut.clk, clk_period_ns, units="ns")
        cocotb.start_soon(clock.start())
        self._clock = clock

        # latch optional hierarchical handles (safe if not present)
        self._core = getattr(dut, "game_inst", None)
        self._dbg_deal_count = getattr(self._core, "dbg_deal_count", None) if self._core else None
        self._dbg_last_card  = getattr(self._core, "dbg_last_card",  None) if self._core else None
        self._dbg_blackjack  = getattr(self._core, "dbg_blackjack",  None) if self._core else None
        self._user_total     = getattr(self._core, "user_total",     None) if self._core else None
        self._dealer_total   = getattr(self._core, "dealer_total",   None) if self._core else None
        self._balance        = getattr(self._core, "balance",        None) if self._core else None

    # ------------------------- basic controls -------------------------

    async def reset(self, pre_cycles=2, hold_cycles=10, post_cycles=5):
        """Apply a clean synchronous reset with ena high."""
        self._dut._log.info("Reset")
        self._dut.ena.value   = 1
        self._dut.ui_in.value = NOT_PUSHED
        self._dut.uio_in.value = 0

        # ensure stable clock before asserting reset
        await ClockCycles(self._dut.clk, pre_cycles)

        # assert reset (active-low)
        self._dut.rst_n.value = 0
        await ClockCycles(self._dut.clk, hold_cycles)

        # deassert reset
        self._dut.rst_n.value = 1
        await ClockCycles(self._dut.clk, post_cycles)

    async def _press(self, mask: int, press_cycles=3, release_cycles=1):
        """
        Press a button mask for 'press_cycles' clocks, then release.
        Supports multi-button presses by OR-ing masks.
        """
        self._dut.ui_in.value = mask
        await ClockCycles(self._dut.clk, press_cycles)
        self._dut.ui_in.value = NOT_PUSHED
        await ClockCycles(self._dut.clk, release_cycles)

    # ------------------------- user actions -------------------------

    async def start(self):
        """Press START to begin a round."""
        await self._press(BTN_START)

    async def hit(self):
        """Player HIT (take a card)."""
        await self._press(BTN_HIT)

    async def stand(self):
        """Player STAND (end turn)."""
        await self._press(BTN_STAND)

    async def double(self):
        """Player DOUBLE (one card then end turn)."""
        await self._press(BTN_DOUBLE)

    async def hit_and_wait(self, settle_cycles=3):
        """HIT and wait a few cycles for totals to update."""
        await self.hit()
        await ClockCycles(self._dut.clk, settle_cycles)

    async def double_and_wait(self, settle_cycles=3):
        """DOUBLE and wait a few cycles for totals to update."""
        await self.double()
        await ClockCycles(self._dut.clk, settle_cycles)

    # ------------------------- waits & reads -------------------------

    async def wait_initial_deal(self, timeout_cycles=2000):
        """
        Wait until initial deal completes (user gets 2, dealer 1).
        If dbg_deal_count is available, wait for it to reach 3.
        Otherwise, just wait a conservative number of cycles.
        """
        if self._dbg_deal_count is None:
            # fallback: just wait a bit
            await ClockCycles(self._dut.clk, 16)
            return True

        for _ in range(timeout_cycles):
            await RisingEdge(self._dut.clk)
            if int(self._dbg_deal_count.value) == 3:
                return True
        raise TimeoutError("Timed out waiting for initial deal (dbg_deal_count != 3)")

    async def wait_until_dealer_done(self, timeout_cycles=5000):
        """
        Wait for dealer drawing phase to complete.
        If dealer_total is readable, wait until it stops increasing
        or reaches >= 17 for several stable cycles; else, just wait.
        """
        if self._dealer_total is None:
            await ClockCycles(self._dut.clk, 64)
            return True

        stable_needed = 5
        stable = 0
        last_val = int(self._dealer_total.value)
        for _ in range(timeout_cycles):
            await RisingEdge(self._dut.clk)
            cur = int(self._dealer_total.value)
            # consider done when >=17 and stable for a few cycles
            if cur >= 17:
                if cur == last_val:
                    stable += 1
                    if stable >= stable_needed:
                        return True
                else:
                    stable = 0
            last_val = cur
        raise TimeoutError("Timed out waiting for dealer to finish")

    # Optional reads (return None if hierarchy isn’t available)

    def read_deal_count_now(self):
        return int(self._dbg_deal_count.value) if self._dbg_deal_count is not None else None

    def read_last_card_now(self):
        return int(self._dbg_last_card.value) if self._dbg_last_card is not None else None

    def read_blackjack_now(self):
        return int(self._dbg_blackjack.value) if self._dbg_blackjack is not None else None

    def read_user_total_now(self):
        return int(self._user_total.value) if self._user_total is not None else None

    def read_dealer_total_now(self):
        return int(self._dealer_total.value) if self._dealer_total is not None else None

    def read_balance_now(self):
        return int(self._balance.value) if self._balance is not None else None

    # ------------------------- round helpers -------------------------

    async def start_and_wait_deal(self):
        """Start a new round and wait until the initial deal finishes."""
        await self.start()
        return await self.wait_initial_deal()

    async def play_player_turn(self, do_double=False, num_hits=0, settle_cycles=3):
        """
        Play the player's turn with a scripted strategy:
        - if do_double: press DOUBLE (takes one card & ends turn)
        - else: press HIT 'num_hits' times and then STAND
        """
        if do_double:
            await self.double_and_wait(settle_cycles)
            return

        for _ in range(max(0, int(num_hits))):
            await self.hit_and_wait(settle_cycles)
        await self.stand()
        await ClockCycles(self._dut.clk, settle_cycles)

    async def play_round(self, do_double=False, num_hits=0, settle_cycles=3):
        """
        Full round flow:
          1) START + wait initial deal
          2) Player actions (double or hits+stand)
          3) Wait dealer to finish
          4) Wait a few cycles for settlement
        Returns a dict with any observable stats (None if not visible).
        """
        await self.start_and_wait_deal()
        await self.play_player_turn(do_double=do_double, num_hits=num_hits, settle_cycles=settle_cycles)
        await self.wait_until_dealer_done()
        await ClockCycles(self._dut.clk, 8)

        return {
            "user_total":   self.read_user_total_now(),
            "dealer_total": self.read_dealer_total_now(),
            "balance":      self.read_balance_now(),
            "blackjack":    self.read_blackjack_now(),
            "deal_count":   self.read_deal_count_now(),
        }

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    dut._log.info("Test project behavior")

    # Set the input values you want to test
    dut.ui_in.value = 20
    dut.uio_in.value = 30

    # Wait for one clock cycle to see the output values
    await ClockCycles(dut.clk, 1)

    # The following assersion is just an example of how to check the output values.
    # Change it to match the actual expected output of your module:
    assert dut.uo_out.value == 50

    # Keep testing the module by changing the input values, waiting for
    # one or more clock cycles, and asserting the expected output values.
