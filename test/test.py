# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge
import random

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
    - Optional reads of internal debug signals when hierarchy is visible:
        game_inst.dbg_deal_count
        game_inst.dbg_last_card
        game_inst.dbg_blackjack
        game_inst.user_total
        game_inst.dealer_total
        game_inst.balance
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
        """Apply a clean reset with ena high."""
        self._dut._log.info("Reset")
        self._dut.ena.value    = 1
        self._dut.ui_in.value  = NOT_PUSHED
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
        """Press a button mask for press_cycles clocks, then release."""
        self._dut.ui_in.value = mask
        await ClockCycles(self._dut.clk, press_cycles)
        self._dut.ui_in.value = NOT_PUSHED
        await ClockCycles(self._dut.clk, release_cycles)

    # ------------------------- user actions -------------------------

    async def start(self):
        await self._press(BTN_START)

    async def hit(self):
        await self._press(BTN_HIT)

    async def stand(self):
        await self._press(BTN_STAND)

    async def double(self):
        await self._press(BTN_DOUBLE)

    async def hit_and_wait(self, settle_cycles=3):
        await self.hit()
        await ClockCycles(self._dut.clk, settle_cycles)

    async def double_and_wait(self, settle_cycles=3):
        await self.double()
        await ClockCycles(self._dut.clk, settle_cycles)

    # ------------------------- waits & reads -------------------------

    async def wait_initial_deal(self, timeout_cycles=2000):
        """
        Wait until initial deal completes (user gets 2, dealer 1).
        If dbg_deal_count is available, wait for it to reach 3.
        Otherwise, wait a conservative number of cycles.
        """
        if self._dbg_deal_count is None:
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
        If dealer_total is readable, wait until it stops changing at >=17 for a few cycles.
        Otherwise, wait a conservative number of cycles.
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
        await self.start()
        return await self.wait_initial_deal()

    async def play_player_turn(self, do_double=False, num_hits=0, settle_cycles=3):
        if do_double:
            await self.double_and_wait(settle_cycles)
            return

        for _ in range(max(0, int(num_hits))):
            await self.hit_and_wait(settle_cycles)

        await self.stand()
        await ClockCycles(self._dut.clk, settle_cycles)

    async def play_round(self, do_double=False, num_hits=0, settle_cycles=3):
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

    # ------------------------- RNG seeding -------------------------

    async def load_seed(self, seed=0xACE1):
        """
        Load deterministic RNG seed (ONLY if the top exposes rng_seed/rng_load).
        If ports don't exist, this will safely skip (won't fail tests).
        """
        if not hasattr(self._dut, "rng_seed") or not hasattr(self._dut, "rng_load"):
            self._dut._log.warning("No rng_seed/rng_load ports on DUT; skipping seed load.")
            return False

        self._dut.rng_seed.value = seed
        self._dut.rng_load.value = 1
        await ClockCycles(self._dut.clk, 1)
        self._dut.rng_load.value = 0
        await ClockCycles(self._dut.clk, 1)
        return True


# -----------------------------------------------------------------------------
#  Basic functionality tests (your existing ones, kept)
# -----------------------------------------------------------------------------

@cocotb.test()
async def test_reset_and_default_balance(dut):
    """Verify that reset works and the initial balance is 500."""
    game = GameDriver(dut)
    await game.reset()

    bal = game.read_balance_now()
    if bal is not None:
        assert bal == 500, f"Expected balance 500 after reset, got {bal}"


@cocotb.test()
async def test_start_initial_deal_completes(dut):
    """Press START and verify that the initial deal finishes (3 total cards drawn)."""
    game = GameDriver(dut)
    await game.reset()

    await game.start()
    assert await game.wait_initial_deal(), "Initial deal did not complete"

    deal_cnt = game.read_deal_count_now()
    if deal_cnt is not None:
        assert deal_cnt == 3, f"Expected deal_count == 3, got {deal_cnt}"

    u = game.read_user_total_now()
    d = game.read_dealer_total_now()
    if u is not None:
        assert u > 0, f"User total should be >0 after initial deal, got {u}"
    if d is not None:
        assert d >= 0, f"Dealer total should be >=0 after initial deal, got {d}"


@cocotb.test()
async def test_double_ends_player_turn(dut):
    """Verify that DOUBLE action ends player's turn and triggers dealer phase."""
    game = GameDriver(dut)
    await game.reset()
    await game.start_and_wait_deal()

    await game.double_and_wait()
    await game.wait_until_dealer_done()

    d = game.read_dealer_total_now()
    if d is not None:
        assert d >= 17, f"Dealer expected to finish at >=17, got {d}"


@cocotb.test()
async def test_stand_triggers_dealer_phase(dut):
    """Verify that STAND immediately starts dealer phase."""
    game = GameDriver(dut)
    await game.reset()
    await game.start_and_wait_deal()

    await game.stand()
    await game.wait_until_dealer_done()

    d = game.read_dealer_total_now()
    if d is not None:
        assert d >= 17, f"Dealer expected to finish at >=17, got {d}"


@cocotb.test()
async def test_settlement_balance_delta_is_valid(dut):
    """
    Verify that after a round completes, balance change is one of valid values:
    - Normal round: {-50, 0, +50}
    - Natural blackjack: +75 (per current implementation)
    (Double-bet deltas are handled in a separate test)
    """
    game = GameDriver(dut)
    await game.reset()
    bal_before = game.read_balance_now()

    await game.start_and_wait_deal()
    bj = game.read_blackjack_now()

    await game.stand()
    await game.wait_until_dealer_done()
    await ClockCycles(dut.clk, 4)

    bal_after = game.read_balance_now()
    if bal_before is None or bal_after is None:
        return

    delta = bal_after - bal_before
    valid_regular = {-50, 0, +50}
    valid_blackjack = {+75}

    if bj is not None and bj == 1:
        assert delta in valid_blackjack, f"Blackjack payout expected +75, got {delta}"
    else:
        assert delta in valid_regular, f"Settlement delta invalid: {delta}"


@cocotb.test()
async def test_bust_flows_to_settlement(dut):
    """If user exceeds 21, verify that game moves to settlement and balance updates."""
    game = GameDriver(dut)
    await game.reset()
    bal0 = game.read_balance_now()

    await game.start_and_wait_deal()

    for _ in range(6):
        await game.hit_and_wait()

    await game.wait_until_dealer_done()
    await ClockCycles(dut.clk, 8)

    bal1 = game.read_balance_now()
    if bal0 is not None and bal1 is not None:
        assert bal1 != bal0, "Balance did not change after bust round"


@cocotb.test()
async def test_multiple_rounds_smoke(dut):
    """Smoke test: run several random rounds and ensure no deadlocks / sane balance."""
    game = GameDriver(dut)
    await game.reset()

    for _ in range(8):
        await game.start_and_wait_deal()

        if random.randint(0, 3) == 0:
            await game.double_and_wait()
        else:
            for _ in range(random.randint(0, 2)):
                await game.hit_and_wait()
            await game.stand()

        await game.wait_until_dealer_done()
        await ClockCycles(dut.clk, 6)

        bal = game.read_balance_now()
        if bal is not None:
            assert 0 <= bal <= 2000, f"Balance out of sane range: {bal}"


@cocotb.test()
async def test_buttons_ignored_before_start(dut):
    """Verify HIT/STAND/DOUBLE before START do not change totals or balance."""
    game = GameDriver(dut)
    await game.reset()

    bal0 = game.read_balance_now()
    u0   = game.read_user_total_now()
    d0   = game.read_dealer_total_now()

    await game.hit_and_wait()
    await game.double_and_wait()
    await game.stand()
    await ClockCycles(dut.clk, 10)

    bal1 = game.read_balance_now()
    u1   = game.read_user_total_now()
    d1   = game.read_dealer_total_now()

    if bal0 is not None and bal1 is not None:
        assert bal1 == bal0, f"Balance changed before START: {bal0} -> {bal1}"
    if u0 is not None and u1 is not None:
        assert u1 == u0, f"User total changed before START: {u0} -> {u1}"
    if d0 is not None and d1 is not None:
        assert d1 == d0, f"Dealer total changed before START: {d0} -> {d1}"


@cocotb.test()
async def test_reset_mid_round_clears_state(dut):
    """Start a round, deal some cards, then reset; verify state returns to initial."""
    game = GameDriver(dut)
    await game.reset()

    await game.start_and_wait_deal()
    await game.hit_and_wait()

    await game.reset()

    u_after = game.read_user_total_now()
    d_after = game.read_dealer_total_now()
    bal_after = game.read_balance_now()

    if u_after is not None:
        assert u_after == 0, f"user_total not cleared by reset: {u_after}"
    if d_after is not None:
        assert d_after == 0, f"dealer_total not cleared by reset: {d_after}"
    if bal_after is not None:
        assert bal_after == 500, f"balance after reset != 500: {bal_after}"


@cocotb.test()
async def test_double_round_balance_delta_is_100(dut):
    """Run multiple rounds with DOUBLE and verify non-zero delta is ±100."""
    game = GameDriver(dut)
    await game.reset()

    for _ in range(10):
        bal_before = game.read_balance_now()
        stats = await game.play_round(do_double=True, num_hits=0)
        bal_after = game.read_balance_now()

        if bal_before is None or bal_after is None:
            continue

        delta = bal_after - bal_before
        if delta != 0:
            assert delta in {-100, 100}, (
                f"DOUBLE round delta should be ±100, got {delta} "
                f"(user_total={stats['user_total']}, dealer_total={stats['dealer_total']})"
            )


@cocotb.test()
async def test_push_keeps_balance_when_observed(dut):
    """
    If a push (user_total == dealer_total <=21) is observed, balance delta must be 0.
    If no push seen, warn but don't fail.
    """
    game = GameDriver(dut)
    await game.reset()

    seen_push = False

    for _ in range(80):
        bal_before = game.read_balance_now()
        stats = await game.play_round(do_double=False, num_hits=random.randint(0, 2))
        bal_after = game.read_balance_now()

        u = stats["user_total"]
        d = stats["dealer_total"]

        if None in (bal_before, bal_after, u, d):
            continue

        if u <= 21 and d <= 21 and u == d:
            seen_push = True
            assert (bal_after - bal_before) == 0, (
                f"Push (u=d={u}) should keep balance, got delta={bal_after - bal_before}"
            )
            break

    if not seen_push:
        dut._log.warning("No push observed in 80 rounds; push behavior not exercised.")


@cocotb.test()
async def test_wait_until_blackjack_then_check_payout(dut):
    """
    Run rounds until we observe a blackjack, then verify:
      - blackjack flag == 1 (if visible)
      - user_total == 21 (if visible)
      - balance delta == +75 (if visible)
    No RTL changes. May take many rounds (non-deterministic).
    """
    game = GameDriver(dut)
    await game.reset()

    # Require visibility of balance at least, otherwise we can't check payout
    if game.read_balance_now() is None:
        dut._log.warning("Balance not visible via hierarchy; cannot verify blackjack payout.")
        return

    max_rounds = 20000  # "כמה שצריך" - אפשר להעלות גם ל-100k אם בא לך
    prev_balance = game.read_balance_now()

    for i in range(max_rounds):
        # Play a minimal round (no hits) so we don't miss "natural blackjack"
        await game.start_and_wait_deal()

        bj_flag = game.read_blackjack_now()
        u_total = game.read_user_total_now()

        # Detect blackjack:
        # - Prefer bj_flag if available
        # - Fallback: user_total==21 right after initial deal (typical natural blackjack)
        is_bj = False
        if bj_flag is not None:
            is_bj = (bj_flag == 1)
        elif u_total is not None:
            is_bj = (u_total == 21)

        # Finish the round the same way your other tests do
        await game.stand()
        await game.wait_until_dealer_done()
        await ClockCycles(dut.clk, 4)

        cur_balance = game.read_balance_now()

        if is_bj:
            dut._log.info(f" Blackjack observed on round {i+1}/{max_rounds}")
            dut._log.info(f"   bj_flag={bj_flag}, user_total={u_total}, balance {prev_balance}->{cur_balance}")

            # Strong asserts if signals are visible
            if bj_flag is not None:
                assert bj_flag == 1, f"Expected bj_flag=1, got {bj_flag}"
            if u_total is not None:
                assert u_total == 21, f"Expected user_total=21 on blackjack, got {u_total}"

            assert (cur_balance - prev_balance) == 75, (
                f"Expected blackjack payout +75, got {cur_balance - prev_balance}"
            )
            return  # done!

        # not BJ -> continue
        prev_balance = cur_balance

    assert False, f"Did not observe blackjack in {max_rounds} rounds (non-deterministic)."


@cocotb.test()
async def test_balance_never_negative_over_many_rounds(dut):
    """Stress test: run random rounds; balance should never go negative."""
    game = GameDriver(dut)
    await game.reset()

    for _ in range(50):
        do_double = (random.randint(0, 3) == 0)  # ~25%
        num_hits = random.randint(0, 3)

        await game.play_round(do_double=do_double, num_hits=num_hits)

        bal = game.read_balance_now()
        if bal is not None:
            assert bal >= 0, f"Balance became negative: {bal}"


# -----------------------------------------------------------------------------
#  NEW tests (protocol + determinism hooks)
# -----------------------------------------------------------------------------

@cocotb.test()
async def test_start_ignored_mid_round(dut):
    """
    Press START during an active round; totals should not reset/re-deal.
    (If your intended behavior is "restart round", change assertions accordingly.)
    """
    game = GameDriver(dut)
    await game.reset()

    await game.start_and_wait_deal()
    u_before = game.read_user_total_now()
    d_before = game.read_dealer_total_now()
    dc_before = game.read_deal_count_now()

    await game.start()  # start again mid-round
    await ClockCycles(dut.clk, 12)

    u_after = game.read_user_total_now()
    d_after = game.read_dealer_total_now()
    dc_after = game.read_deal_count_now()

    if u_before is not None and u_after is not None:
        assert u_after == u_before, f"START mid-round changed user_total: {u_before}->{u_after}"
    if d_before is not None and d_after is not None:
        assert d_after == d_before, f"START mid-round changed dealer_total: {d_before}->{d_after}"
    if dc_before is not None and dc_after is not None:
        assert dc_after == dc_before, f"START mid-round changed deal_count: {dc_before}->{dc_after}"


@cocotb.test()
async def test_simultaneous_hit_and_stand_defined_behavior(dut):
    """
    Press HIT|STAND simultaneously. This should have a defined behavior:
    - either ignored, or
    - one has priority.
    Here we assert it does NOT deadlock and still reaches dealer-done after we STAND.
    """
    game = GameDriver(dut)
    await game.reset()
    await game.start_and_wait_deal()

    # Multi-press for a couple cycles
    await game._press(BTN_HIT | BTN_STAND, press_cycles=2, release_cycles=1)

    # Ensure we can still finish the round
    await game.stand()
    await game.wait_until_dealer_done()
    await ClockCycles(dut.clk, 4)

    d = game.read_dealer_total_now()
    if d is not None:
        assert d >= 17, f"Dealer didn't finish properly after simultaneous press, dealer_total={d}"


@cocotb.test()
async def test_hold_hit_is_not_auto_repeat_spam(dut):
    """
    Hold HIT for a long time. This should NOT cause uncontrolled repeated hits
    (unless your design is level-sensitive by intent).
    We only assert the total doesn't grow insanely and the design keeps running.
    """
    game = GameDriver(dut)
    await game.reset()
    await game.start_and_wait_deal()

    u0 = game.read_user_total_now()

    # Hold HIT level for 50 cycles
    dut.ui_in.value = BTN_HIT
    await ClockCycles(dut.clk, 50)
    dut.ui_in.value = NOT_PUSHED
    await ClockCycles(dut.clk, 10)

    u1 = game.read_user_total_now()

    if u0 is not None and u1 is not None:
        # A single HIT is at most +11. If your design debounces/pulses internally,
        # you'd expect <= +11. If your design is level-sensitive, this might be higher.
        # We'll enforce a "not insane" bound; tighten to <=11 if that's your intent.
        assert (u1 - u0) <= 22, f"Holding HIT caused too many hits: u0={u0}, u1={u1}"

    # Ensure we can still complete round
    await game.stand()
    await game.wait_until_dealer_done()


@cocotb.test()
async def test_double_after_hit_is_ignored_or_not_full_double(dut):
    """
    Common rule: double is only allowed as first action.
    This test checks that after doing HIT once, pressing DOUBLE does not apply ±100 payout.
    If your intended behavior is different, adjust accordingly.
    """
    game = GameDriver(dut)
    await game.reset()
    await game.start_and_wait_deal()

    await game.hit_and_wait()

    bal0 = game.read_balance_now()

    await game.double_and_wait()
    await game.wait_until_dealer_done()
    await ClockCycles(dut.clk, 4)

    bal1 = game.read_balance_now()
    if bal0 is None or bal1 is None:
        return

    delta = bal1 - bal0
    assert delta not in (-100, 100), (
        f"DOUBLE-after-HIT looked like a full double payout (delta={delta}). "
        "If you *do* allow double after hit, change this test."
    )


@cocotb.test()
async def test_deterministic_seed_round_smoke(dut):
    """
    If rng_seed/rng_load exist on the DUT, load a seed and run a round.
    This test does NOT enforce exact totals (you can lock those later),
    it just proves the seed API works and the game progresses.
    """
    game = GameDriver(dut)
    await game.reset()

    seeded = await game.load_seed(0x1234)
    if not seeded:
        dut._log.warning("Skipping deterministic seed test: no rng_seed/rng_load ports.")
        return

    await game.start_and_wait_deal()
    await game.hit_and_wait()
    await game.stand()
    await game.wait_until_dealer_done()
    await ClockCycles(dut.clk, 4)

    # Basic sanity: totals visible and within bounds if available
    u = game.read_user_total_now()
    d = game.read_dealer_total_now()
    if u is not None:
        assert 0 <= u <= 31, f"user_total out of expected bounds: {u}"
    if d is not None:
        assert 0 <= d <= 31, f"dealer_total out of expected bounds: {d}"
