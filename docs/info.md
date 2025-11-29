<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works
 
The project is a simplified Blackjack game implemented entirely in digital hardware.
The core game logic (cards, rules and balance) runs as a finite-state machine, and a
16-bit LFSR is used as a pseudo-random card generator.
The player interacts with the game using push-buttons (Hit / Stand / Double / Start),
and the internal state can be visualized via a VGA “blackjack table” screen.
All logic is fully synthesizable and fits into a single TinyTapeout tile.

Short description of the modules involved:

## tt_um_AmitChen1415.v
Top module of the project. Connects all sub-modules and maps the TinyTapeout
I/O pins to the internal signals.
ui_in bits are used as the player buttons (Start / Hit / Stand / Double), and
uo_out is currently wired to the VGA signals for visual debugging.
Instantiates the blackjack_core game engine and the reset-synchronizer.

## blackjack_core.v
Heart of the design – implements the Blackjack rules as a finite state machine.
Handles the full round flow: initial deal (2 cards to player, 1 to dealer), player
actions (Hit / Stand / Double), dealer drawing until 17, and final result
computation.
Maintains the player and dealer totals, checks for bust / win / push, detects a
natural blackjack, and updates the chip balance accordingly.
Uses the card RNG to draw new card values.

## rng_card.v
Small wrapper around the 16-bit LFSR that converts its raw random value into a
valid card value in the range 2–11 (2–10 and Ace=11).
Used by blackjack_core whenever a new card needs to be dealt.

## lfsr16.v
16-bit Linear Feedback Shift Register used as a pseudo-random number generator.
Can be reset to a default non-zero state or loaded with a custom seed.
Provides a deterministic but “random-looking” sequence suitable for the game’s
card draws.

## pwrup_synchronizer.v
Two-flip-flop synchronizer for the active-low reset.
Ensures that the reset signal is safely synchronized to the internal clock
before releasing the rest of the logic from reset, avoiding metastability at
power-up.

## vga_controller.v
Generates the standard 640×480@60Hz VGA timing: horizontal/vertical counters,
hsync and vsync pulses.
Provides the current pixel coordinates (x, y) that are used by the graphics
module to decide which color each pixel should be.

## blackjack_table.v
Pixel-generator for the VGA output. Uses the (x, y) coordinates from
vga_controller to draw a green felt background, the dealer and player cards,
the “BLACKJACK” title in the center, a “BALANCE: $1100” label on the left, and a
face-down card deck on the right.
Implements a small 5×7 font and simple shapes (rectangles, borders, checker
patterns) to render the table layout.

## How to test

Explain how to use your project

## External hardware

List external hardware used in your project (e.g. PMOD, LED display, etc), if any
