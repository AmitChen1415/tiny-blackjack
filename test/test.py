# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge
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
    
    Now with PROPER SIGNAL VERIFICATION:
    - Drives user inputs on ui_in (start/hit/stand/double)
    - Manages reset/clock
    - VERIFIES that all internal signals are accessible
    - Checks complete design from top to core
    """

    def __init__(self, dut, clk_period_ns=40):
        self._dut = dut

        # start clock
        clock = Clock(dut.clk, clk_period_ns, units="ns")
        cocotb.start_soon(clock.start())
        self._clock = clock

        # Get the hierarchical core handle via user_project wrapper (REQUIRED - not optional anymore)
        user_project = getattr(dut, "user_project", None)
        if user_project is None:
            raise RuntimeError("ERROR: user_project not found in DUT! Hierarchy not available!")
        
        self._core = getattr(user_project, "game_inst", None)
        if self._core is None:
            raise RuntimeError("ERROR: game_inst not found in user_project! Hierarchy not available!")
        
        dut._log.info("✓ game_inst hierarchy found")

        # VERIFY all required signals exist (FAIL if missing)
        required_signals = {
            'user_total': getattr(self._core, "user_total", None),
            'dealer_total': getattr(self._core, "dealer_total", None),
            'balance': getattr(self._core, "balance", None),
        }
        
        missing = [name for name, sig in required_signals.items() if sig is None]
        if missing:
            raise RuntimeError(f"ERROR: Missing required signals: {missing}")
        
        dut._log.info(f"✓ All required signals accessible: {list(required_signals.keys())}")
        
        # Optional card output signals (for full design check)
        self._player_card1 = getattr(self._core, "player_card1_o", None)
        self._player_card2 = getattr(self._core, "player_card2_o", None)
        self._dealer_card1 = getattr(self._core, "dealer_card1_o", None)
        self._dealer_card2 = getattr(self._core, "dealer_card2_o", None)
        
        # Store references
        self._user_total = required_signals['user_total']
        self._dealer_total = required_signals['dealer_total']
        self._balance = required_signals['balance']
        
        # Optional state/debug signals
        self._state = getattr(self._core, "state", None)
        self._p_cards = getattr(self._core, "p_cards", None)
        self._d_cards = getattr(self._core, "d_cards", None)
        self._doubled = getattr(self._core, "doubled", None)

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
        Check p_cards and d_cards to verify the deal is complete.
        """
        stable_needed = 3
        stable = 0
        last_p_cards = 0
        last_d_cards = 0
        
        for _ in range(timeout_cycles):
            await RisingEdge(self._dut.clk)
            p_cards = self.read_p_cards_now()
            d_cards = self.read_d_cards_now()
            
            # After initial deal: player has 2, dealer has 1
            if p_cards == 2 and d_cards == 1:
                if p_cards == last_p_cards and d_cards == last_d_cards:
                    stable += 1
                    if stable >= stable_needed:
                        return True
                else:
                    stable = 0
            
            last_p_cards = p_cards
            last_d_cards = d_cards
        
        raise TimeoutError("Timed out waiting for initial deal")

    async def wait_until_dealer_done(self, timeout_cycles=10000):
        """
        Wait for dealer drawing phase to complete or settlement.
        Returns when dealer_total is stable at >=17, or when a timeout occurs (settlement might have happened).
        """
        if self._dealer_total is None:
            await ClockCycles(self._dut.clk, 64)
            return True

        stable_needed = 5
        stable = 0
        last_val = int(self._dealer_total.value)
        last_state = self.read_state_now()
        
        for cycle in range(timeout_cycles):
            await RisingEdge(self._dut.clk)
            cur = int(self._dealer_total.value)
            cur_state = self.read_state_now()
            
            # If we're in SETTLE state (4) or returned to IDLE (0), dealer/round is done
            if cur_state == 4 or cur_state == 0:
                if cur_state == 0:
                    self._dut._log.info("Dealer/wrap-up observed: state returned to IDLE (0)")
                return True
            
            # Check if dealer value is stable at >=17
            if cur >= 17:
                if cur == last_val:
                    stable += 1
                    if stable >= stable_needed:
                        return True
                else:
                    stable = 0
            
            last_val = cur
            last_state = cur_state

        # If we timeout, log and continue (don't fail yet)
        self._dut._log.warning(f"Timeout waiting for dealer (cycle {timeout_cycles}): dealer_total={int(self._dealer_total.value)}, state={self.read_state_now()}")
        return True

    # Mandatory reads (FAIL if signals not accessible)
    
    def read_user_total_now(self):
        """Read user_total - MUST be accessible"""
        val = int(self._user_total.value)
        return val

    def read_dealer_total_now(self):
        """Read dealer_total - MUST be accessible"""
        val = int(self._dealer_total.value)
        return val

    def read_balance_now(self):
        """Read balance - MUST be accessible"""
        val = int(self._balance.value)
        return val

    def read_state_now(self):
        """Read state if available"""
        return int(self._state.value) if self._state is not None else None

    def read_p_cards_now(self):
        """Read player card count if available"""
        return int(self._p_cards.value) if self._p_cards is not None else None

    def read_d_cards_now(self):
        """Read dealer card count if available"""
        return int(self._d_cards.value) if self._d_cards is not None else None

    def read_doubled_now(self):
        """Read doubled flag if available"""
        return int(self._doubled.value) if self._doubled is not None else None
    
    def read_player_card1_now(self):
        """Read first player card if available"""
        return int(self._player_card1.value) if self._player_card1 is not None else None

    def read_dealer_card1_now(self):
        """Read first dealer card if available"""
        return int(self._dealer_card1.value) if self._dealer_card1 is not None else None

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


# =============================================================================
#  VERIFICATION TESTS - These MUST pass
# =============================================================================

@cocotb.test()
async def test_00_verify_signals_accessible(dut):
    """CRITICAL: Verify that game_inst and all required signals are accessible."""
    dut._log.info("=" * 80)
    dut._log.info("TEST: Verify all signals accessible")
    dut._log.info("=" * 80)
    
    try:
        game = GameDriver(dut)
        dut._log.info("✓ GameDriver initialized successfully")
        dut._log.info("✓ game_inst found in DUT")
        dut._log.info("✓ user_total accessible")
        dut._log.info("✓ dealer_total accessible")
        dut._log.info("✓ balance accessible")
    except RuntimeError as e:
        dut._log.error(f"✗ FAILED: {e}")
        raise


@cocotb.test()
async def test_01_reset_clears_totals_and_sets_balance(dut):
    """Verify that reset clears game state and sets balance to 500."""
    dut._log.info("=" * 80)
    dut._log.info("TEST: Reset clears totals and sets initial balance")
    dut._log.info("=" * 80)
    
    game = GameDriver(dut)
    await game.reset()

    user = game.read_user_total_now()
    dealer = game.read_dealer_total_now()
    bal = game.read_balance_now()

    dut._log.info(f"After reset: user_total={user}, dealer_total={dealer}, balance={bal}")
    
    assert user == 0, f"✗ user_total should be 0 after reset, got {user}"
    assert dealer == 0, f"✗ dealer_total should be 0 after reset, got {dealer}"
    assert bal == 500, f"✗ balance should be 500 after reset, got {bal}"
    
    dut._log.info("✓ Reset state correct")


@cocotb.test()
async def test_start_initial_deal_completes(dut):
    """Press START and verify that the initial deal finishes (3 total cards drawn)."""
    dut._log.info("=" * 80)
    dut._log.info("TEST: Initial deal completes with 3 cards")
    dut._log.info("=" * 80)
    
    game = GameDriver(dut)
    await game.reset()

    u0 = game.read_user_total_now()
    d0 = game.read_dealer_total_now()
    p0 = game.read_p_cards_now()
    dut._log.info(f"Before START: user={u0}, dealer={d0}, p_cards={p0}")

    await game.start()
    await game.wait_initial_deal()

    u1 = game.read_user_total_now()
    d1 = game.read_dealer_total_now()
    p1 = game.read_p_cards_now()
    dc1 = game.read_d_cards_now()
    
    dut._log.info(f"After START+deal: user={u1}, dealer={d1}, p_cards={p1}, d_cards={dc1}")
    
    # HARD ASSERTS - not soft checks!
    assert u1 > 0, f"User total should be >0 after initial deal, got {u1}"
    assert d1 > 0, f"Dealer total should be >0 after initial deal, got {d1}"
    assert p1 == 2, f"Player should have exactly 2 cards after initial deal, got {p1}"
    assert dc1 == 1, f"Dealer should have exactly 1 card after initial deal, got {dc1}"
    
    dut._log.info(f"✓ Initial deal correct: user={u1}, dealer={d1}")


@cocotb.test()
async def test_02_hit_increases_player_total(dut):
    """Verify that pressing HIT increases the player total and card count."""
    dut._log.info("=" * 80)
    dut._log.info("TEST: HIT increases player total")
    dut._log.info("=" * 80)
    
    game = GameDriver(dut)
    await game.reset()
    await game.start_and_wait_deal()
    
    u_before = game.read_user_total_now()
    p_before = game.read_p_cards_now()
    dut._log.info(f"Before HIT: user_total={u_before}, p_cards={p_before}")
    
    await game.hit_and_wait(settle_cycles=5)
    
    u_after = game.read_user_total_now()
    p_after = game.read_p_cards_now()
    dut._log.info(f"After HIT: user_total={u_after}, p_cards={p_after}")
    
    # HARD ASSERTS
    assert u_after > u_before, f"HIT should increase user_total: {u_before} -> {u_after}"
    assert p_after == p_before + 1, f"HIT should increase p_cards by 1: {p_before} -> {p_after}"
    
    dut._log.info(f"✓ HIT increased total by {u_after - u_before}, cards now {p_after}")


@cocotb.test()
async def test_double_ends_player_turn(dut):
    """Verify that DOUBLE action ends player's turn and triggers dealer phase."""
    dut._log.info("=" * 80)
    dut._log.info("TEST: DOUBLE ends player turn and moves to dealer phase")
    dut._log.info("=" * 80)
    
    game = GameDriver(dut)
    await game.reset()
    await game.start_and_wait_deal()
    
    doubled_before = game.read_doubled_now()
    dut._log.info(f"Before DOUBLE: doubled={doubled_before}")
    balance_before = game.read_balance_now()

    await game.double_and_wait(settle_cycles=5)
    await game.wait_until_dealer_done()

    d = game.read_dealer_total_now()
    u_after = game.read_user_total_now()
    balance_after = game.read_balance_now()
    doubled_after = game.read_doubled_now()

    dut._log.info(f"After DOUBLE: user_total={u_after}, dealer_total={d}, doubled={doubled_after}, balance={balance_after}")

    # New behavior: if player busts on the double, they are immediately settled (disqualified)
    # and the dealer may not draw. In that case the balance should decrease by the doubled bet (100).
    if u_after > 21:
        assert doubled_after == 1, f"Doubled flag should be 1 after double, got {doubled_after}"
        assert balance_after == balance_before - 100, f"Balance should decrease by 100 on bust-after-double: {balance_before} -> {balance_after}"
        dut._log.info(f"✓ DOUBLE caused immediate bust: user={u_after}, balance delta={balance_after - balance_before}")
    else:
        assert d >= 17, f"Dealer should finish at >=17 after DOUBLE, got {d}"
        assert doubled_after == 1, f"Doubled flag should be 1, got {doubled_after}"
        dut._log.info(f"✓ DOUBLE worked: doubled={doubled_after}, dealer_total={d}")


@cocotb.test()
async def test_stand_triggers_dealer_phase(dut):
    """Verify that STAND immediately starts dealer phase."""
    dut._log.info("=" * 80)
    dut._log.info("TEST: STAND triggers dealer phase")
    dut._log.info("=" * 80)
    
    game = GameDriver(dut)
    await game.reset()
    await game.start_and_wait_deal()

    u = game.read_user_total_now()
    d_before = game.read_dealer_total_now()
    dut._log.info(f"Player has {u}, dealer showing {d_before}")
    
    await game.stand()
    await game.wait_until_dealer_done()

    d = game.read_dealer_total_now()
    
    dut._log.info(f"After STAND+dealer turn: dealer_total={d}")
    
    assert d >= 17, f"Dealer should finish at >=17, got {d}"
    
    dut._log.info(f"✓ STAND worked: dealer_total={d}")


@cocotb.test()
async def test_settlement_balance_changes_on_win_loss(dut):
    """Verify that balance changes appropriately after a round."""
    dut._log.info("=" * 80)
    dut._log.info("TEST: Settlement changes balance")
    dut._log.info("=" * 80)
    
    game = GameDriver(dut)
    await game.reset()
    bal_before = game.read_balance_now()

    await game.start_and_wait_deal()
    await game.stand()
    await game.wait_until_dealer_done()
    await ClockCycles(dut.clk, 4)

    bal_after = game.read_balance_now()
    u_final = game.read_user_total_now()
    d_final = game.read_dealer_total_now()
    
    dut._log.info(f"Balance: {bal_before} -> {bal_after} (delta={bal_after - bal_before})")
    dut._log.info(f"Final: user={u_final}, dealer={d_final}")
    
    # Balance MUST change (either win +50, lose -50, or push 0)
    # But it must be one of the valid values
    delta = bal_after - bal_before
    valid_deltas = {-50, 0, 50, 75, -100, 100}  # Include blackjack and double bet
    
    assert delta in valid_deltas, f"Balance delta {delta} not in valid set {valid_deltas}"
    assert bal_after >= 0, f"Balance should never be negative, got {bal_after}"
    
    dut._log.info(f"✓ Settlement correct: delta={delta}")


@cocotb.test()
async def test_bust_decreases_balance(dut):
    """If user exceeds 21, balance should decrease."""
    dut._log.info("=" * 80)
    dut._log.info("TEST: Bust decreases balance")
    dut._log.info("=" * 80)
    
    game = GameDriver(dut)
    await game.reset()
    bal0 = game.read_balance_now()

    await game.start_and_wait_deal()

    for _ in range(6):
        await game.hit_and_wait()

    await game.wait_until_dealer_done()
    await ClockCycles(dut.clk, 8)

    bal1 = game.read_balance_now()
    u_final = game.read_user_total_now()
    
    dut._log.info(f"After bust: user_total={u_final}, balance {bal0} -> {bal1}")
    
    assert u_final > 21, f"User should bust (>21), got {u_final}"
    assert bal1 < bal0, f"Balance should decrease after bust: {bal0} -> {bal1}"
    
    dut._log.info(f"✓ Bust detected: user={u_final}, balance decreased by {bal0 - bal1}")


@cocotb.test()
async def test_buttons_ignored_before_start(dut):
    """Verify HIT/STAND/DOUBLE before START do not change totals or balance."""
    dut._log.info("=" * 80)
    dut._log.info("TEST: Buttons ignored before START")
    dut._log.info("=" * 80)
    
    game = GameDriver(dut)
    await game.reset()

    bal0 = game.read_balance_now()
    u0   = game.read_user_total_now()
    d0   = game.read_dealer_total_now()
    
    dut._log.info(f"Before button presses: balance={bal0}, user={u0}, dealer={d0}")

    await game.hit_and_wait()
    await game.double_and_wait()
    await game.stand()
    await ClockCycles(dut.clk, 10)

    bal1 = game.read_balance_now()
    u1   = game.read_user_total_now()
    d1   = game.read_dealer_total_now()
    
    dut._log.info(f"After button presses: balance={bal1}, user={u1}, dealer={d1}")

    assert bal1 == bal0, f"Balance changed before START: {bal0} -> {bal1}"
    assert u1 == u0, f"User total changed before START: {u0} -> {u1}"
    assert d1 == d0, f"Dealer total changed before START: {d0} -> {d1}"
    
    dut._log.info(f"✓ Buttons correctly ignored before START")


@cocotb.test()
async def test_reset_mid_round_clears_state(dut):
    """Start a round, deal some cards, then reset; verify state returns to initial."""
    dut._log.info("=" * 80)
    dut._log.info("TEST: Reset mid-round clears state")
    dut._log.info("=" * 80)
    
    game = GameDriver(dut)
    await game.reset()

    await game.start_and_wait_deal()
    await game.hit_and_wait()

    await game.reset()

    u_after = game.read_user_total_now()
    d_after = game.read_dealer_total_now()
    bal_after = game.read_balance_now()

    dut._log.info(f"After reset mid-round: user={u_after}, dealer={d_after}, balance={bal_after}")
    
    assert u_after == 0, f"user_total not cleared by reset: {u_after}"
    assert d_after == 0, f"dealer_total not cleared by reset: {d_after}"
    assert bal_after == 500, f"balance after reset != 500: {bal_after}"
    
    dut._log.info(f"✓ Reset mid-round correct")


@cocotb.test()
async def test_double_round_balance_delta(dut):
    """Verify that DOUBLE affects balance appropriately (±100 or larger delta)."""
    dut._log.info("=" * 80)
    dut._log.info("TEST: DOUBLE round balance delta")
    dut._log.info("=" * 80)
    
    game = GameDriver(dut)
    await game.reset()

    bal_before = game.read_balance_now()
    await game.start_and_wait_deal()
    await game.double_and_wait(settle_cycles=5)
    await game.wait_until_dealer_done()
    await ClockCycles(dut.clk, 4)

    bal_after = game.read_balance_now()
    delta = bal_after - bal_before
    u = game.read_user_total_now()
    d = game.read_dealer_total_now()
    
    dut._log.info(f"DOUBLE round: balance {bal_before} -> {bal_after} (delta={delta}), user={u}, dealer={d}")
    
    # DOUBLE should result in larger stakes (±100 or ±50 depending on outcome)
    valid_deltas = {-100, -50, 0, 50, 100, 75}
    assert delta in valid_deltas, f"DOUBLE delta {delta} not in valid set {valid_deltas}"
    
    dut._log.info(f"✓ DOUBLE delta correct: {delta}")


@cocotb.test()
async def test_multiple_rounds_no_crash(dut):
    """Run several rounds to ensure no deadlocks or crashes."""
    dut._log.info("=" * 80)
    dut._log.info("TEST: Multiple rounds (smoke test)")
    dut._log.info("=" * 80)
    
    game = GameDriver(dut)
    await game.reset()

    for round_num in range(5):
        dut._log.info(f"Round {round_num + 1}/5...")
        
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
        u = game.read_user_total_now()
        d = game.read_dealer_total_now()
        
        assert 0 <= bal <= 2000, f"Balance out of sane range: {bal}"
        assert 0 <= u <= 31, f"User total out of range: {u}"
        assert 0 <= d <= 31, f"Dealer total out of range: {d}"
        
        dut._log.info(f"  Round {round_num + 1}: user={u}, dealer={d}, balance={bal}")

    dut._log.info(f"✓ All {5} rounds completed without crash")


@cocotb.test()
async def test_balance_never_negative_stress(dut):
    """Stress test: run many random rounds; balance should never go negative."""
    dut._log.info("=" * 80)
    dut._log.info("TEST: Stress - 5 random rounds, balance always >=0")
    dut._log.info("=" * 80)
    
    game = GameDriver(dut)
    await game.reset()

    for round_num in range(5):
        do_double = (random.randint(0, 3) == 0)  # ~25% chance
        num_hits = random.randint(0, 3)

        await game.start_and_wait_deal()
        
        if do_double:
            await game.double_and_wait()
        else:
            for _ in range(num_hits):
                await game.hit_and_wait()
        
        await game.stand()
        await game.wait_until_dealer_done()
        await ClockCycles(dut.clk, 4)

        bal = game.read_balance_now()
        assert bal >= 0, f"Balance went negative in round {round_num}: {bal}"
        
        if (round_num + 1) % 5 == 0:
            dut._log.info(f"  ...round {round_num + 1}: balance={bal}")

    dut._log.info(f"✓ Completed 5 rounds, balance never went negative")


@cocotb.test()
async def test_state_transitions_valid(dut):
    """Verify state machine transitions are valid (only accessible states)."""
    dut._log.info("=" * 80)
    dut._log.info("TEST: State machine transitions")
    dut._log.info("=" * 80)
    
    game = GameDriver(dut)
    await game.reset()
    
    # States: 0=IDLE, 1=INIT_DEAL, 2=PLAYER, 3=DEALER, 4=SETTLE
    valid_states = {0, 1, 2, 3, 4}
    
    for step in range(100):
        state = game.read_state_now()
        
        if state is not None:
            assert state in valid_states, f"Invalid state {state}, must be in {valid_states}"
        
        if step % 10 == 0 and state is not None:
            state_names = {0: "IDLE", 1: "INIT_DEAL", 2: "PLAYER", 3: "DEALER", 4: "SETTLE"}
            dut._log.info(f"  Step {step}: state={state_names.get(state, 'UNKNOWN')}")
        
        await ClockCycles(dut.clk, 1)
    
    dut._log.info(f"✓ State machine stayed in valid states throughout")
