.. _alpha:

Protocol Alpha
==============

This page contains all the relevant information for protocol Alpha, a
development version of the Tezos protocol.

The code can be found in the ``src/proto_alpha`` directory of the
``master`` branch of Tezos.

This page documents the changes brought by protocol Alpha with respect
to Florence.

The main novelties in the Alpha protocol are:

- an upgrade of the consensus algorithm Emmy+ to Emmy*, which brings smaller block times and faster finality
- a 2.5 tez per block subsidy to a CPMM contract to generate liquidity between tez and tzBTC
- gas improvements leading to a 3x to 6x decrease in gas consumption of typical contracts

.. contents:: Here is the complete list of changes:

Emmy*
-----

Emmy* updates Emmy+ by:

- a tweak in the definition of the minimal delay function, and
- an increase in the number of endorsement slots per block

Concretely, in Emmy* a block can be produced with a delay of 30 seconds with respect to the previous block if it has priority 0 and more than 60% of the total endorsing power per block, which has been increased to ``256`` (from ``32``) endorsement slots per block.

The baking and endorsing rewards are updated as follows:

- The reward producing a block at priority 0 is updated from ``e * 1.25`` tez to ``e * 0.078125`` tez, and for producing a block at priority 1 or higher, is updated from ``e * 0.1875`` tez to ``e * 0.011719`` tez, where ``e`` is the endorsing power of the endorsements contained in the block.
- The reward for endorsing a block of priority 0 is updated from ``1.25`` tez to ``0.078125`` tez per endorsement slot, and for endorsing a block at priority 1 or higher is updated from ``0.833333`` tez to ``0.052083`` tez per endorsement slot.

The values of the security deposits are updated from ``512`` tez to ``640`` tez for baking, and from ``64`` tez to ``2.5`` tez for endorsing.

The constant ``hard_gas_limit_per_block`` is updated from ``10,400,000`` to ``5,200,000`` gas units.

The Michelson ``NOW`` instruction keeps the same intuitive meaning,
namely it pushes the minimal injection time on the stack for the
current block. However, this minimal injection time is not 1 minute
after the previous block's timestamp as before, instead it is 30
seconds after.

The values of the ``blocks_per_*`` constants has doubled in order to
match the reduced block times, as follows: ``blocks_per_cycle =
8192``, ``blocks_per_commitment = 64``, ``blocks_per_roll_snapshot =
512``, and ``blocks_per_voting_period = 40960``.

The constant ``time_between_blocks`` is left unchanged at ``[60; 40]`` but the new constant ``minimal_block_delay = 30`` is added.

- `TZIP <https://gitlab.com/tzip/tzip/-/blob/master/drafts/current/draft_emmy-star.md>`__
- MRs: :gl:`!2386` :gl:`!2531` :gl:`!2881`
- Issue: :gl:`#1027`

Liquidity Baking
----------------

2.5 tez per block is credited to a constant product market making (CPMM) contract, the contract's ``%default`` entrypoint is called to update its storage, and the credit is included in block metadata as a balance update with a new ``update_origin`` type, ``Subsidy``.

The liquidity baking subsidy shuts off automatically at a fixed level if not renewed in a future upgrade. The sunset level is included in constants.

At any time bakers can vote to shut off the liquidity baking subsidy by setting a boolean flag in protocol_data. An exponential moving average (ema) of this escape flag is calculated with a window size of 2000 blocks and the subsidy permanently shuts off if the ema is ever over a threshold included in constants (half the window size with precision of 1000 added for integer computation).

- `TZIP <https://gitlab.com/tzip/tzip/-/blob/master/drafts/current/draft-liquidity_baking.md>`__
- MRs: :gl:`!2765` :gl:`!2897` :gl:`!2920` :gl:`!2929` :gl:`!2946`
- Issue: :gl:`#1238`

More detailed docs for liquidity baking can be found :ref:`here<liquidity_baking_alpha>`.

Gas improvements
----------------

- The gas cost of serialization and deserialization of Micheline is divided by 10 thanks to an optimization of the data-encoding library. This reduces the cost of storage operations.
- The gas cost of "small" instructions (e.g., stack manipulation and arithmetic instructions) is divided by 3 to 5 thanks to a significant rewriting of the Michelson interpreter. This reduces the cost of contract execution. (MR :gl:`!2723` :gl:`!2990` :gl:`!3010` :gl:`!3012`)
- The gas cost of most instructions have been re-evaluated. (MR :gl:`!2966` :gl:`!2986` :gl:`!2993`)
- Typically, trading XTZ against a token in Dexter was costing ~50K units of gas, now this operation costs ~10K units of gas. We observed a decrease by a factor of 3 to 6 of the gas consumed by such contracts.

RPC changes
-----------

- Remove deprecated RPCs and deprecated fields in RPC answers related
  to voting periods. (MR :gl:`!2763`; Issue :gl:`#1204`)

- The RPC ``../<block_id>/required_endorsements`` has been removed. (MR :gl:`!2386`)

- Replace `deposit` by `deposits` in `frozen_balance` RPC. (MR :gl:`!2751`)

- All the protocol-specific RPCs under the ``helpers`` path have been
  moved from the protocol to the `recently introduced <tezos!2446>`__ RPC
  plugin. This change should not be visible for end-users but improves
  the maintainability of these RPCs. (MR :gl:`!2811`)

- Added a new RPC for Alpha to retrieve several Big Map values at once:
  ``/chains/<chain_id>/blocks/<block_id>/context/big_maps/<big_map_id>?offset=<int>&length=<int>``.
  This API is meant for dapp developers to improve performance when retrieving
  many values in a big map. (MR :gl:`!2855`)

Metadata changes
----------------

In block metadata, two new fields are added:
- ``liquidity_baking_escape_ema`` representing the new value of the exponential moving average for the liquidity baking escape vote.
- ``implicit_operations_results`` representing results of operations not explicitly appearing in the block, namely migration operations at protocol activation and the liquidity baking subsidy operation at each block.

In turn, two deprecated fields are removed: ``level`` (use ``level_info`` instead) and ``voting_period_kind`` (use ``voting_period_info`` instead). (MR :gl:`!2763`)

In the balance updates of a block metadata, the new origin ``subsidy`` has been introduced, besides the existing ones: ``block application`` and ``protocol migration``. (MR :gl:`!2897`)

Minor changes
-------------

- Realign voting periods with cycles. (MR :gl:`!2838`; Issue :gl:`#1151`)

- Fix dangling temporary big maps preventing originating contracts with fresh big maps or passing fresh big maps to another contract.
  (MR :gl:`!2839`; Issue :gl:`#1154`)

- Typing of `PAIR k` in Michelson no longer promotes `@` annotations
  on the stack to `%` annotations in the result type. (MR :gl:`!2815`)

- Fix overconservative detection of overflows in Michelson mutez multiplication,
  and reported error trace when multiplication is overflowing. (MR :gl:`!2947`; Issues :gl:`#958` :gl:`#972`)

- Fix handling of potential integer overflow in `Time_repr` addition. (MR :gl:`!2660`)

- If gas remains for an operation after it gets executed, the remaining
  gas also gets consumed from the block allowance. (MR :gl:`!2880`)

- Increased the max operation time to live (`max_op_ttl`) from 60 to 120. (MR :gl:`!2828`)

- Other internal refactorings or documentation. (MRs :gl:`!2559` :gl:`!2563` :gl:`!2593` :gl:`!2741` :gl:`!2808` :gl:`!2862` :gl:`!2897` :gl:`!2932` :gl:`!2995`)
