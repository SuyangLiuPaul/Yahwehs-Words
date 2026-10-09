# EV author-authorized lexicon correction — 2026-10-09

## Authorization and scope

The owner supplied the EV author's response: “Thank you for picking up errors in the EV G2304 and H7307. Please correct. Actually, I didn't do anything to change Naves or any Bible versions.” The owner asked to apply it to both Words and Sword. The attached report is the earlier comparison, not a new upstream dictionary package.

## Applied correction

- `assets/thayer.json`, G2304: item 2 now reads `2) spoken of the only and true God`, removing only `, trinity`. The lemma, usage counts, item 1 and items 2a–2c remain intact. A labeled Eagle's View provenance note records the author's authorization.
- H7307: inspected `assets/strongs/hebrew.json` (Simplified/Traditional) and `assets/strongs/bdb_zh.json` in both apps. These entries already lack the EV package's rejected “三一神的第三位……同荣同尊” clause. They are retained unchanged; no replacement definition is invented.
- G2304's existing Chinese definitions also lack the rejected wording and are retained unchanged.
- No Nave's material, Bible edition, scripture, third-party commentary, or unrelated entry is edited. No claim that the author changed those sources is made.

## Repeatable maintenance

`python3 tools/apply_ev_author_corrections.py` performs a guarded dry run; `--write` applies the single entry correction. Unknown or conflicting text causes refusal. The original EV source evidence and the historical report are preserved; their descriptions of the old package remain historical evidence.

This is an application correction authorized by the author, not an assertion that a new EV upstream package has been published. The existing import-following tool now validates this correction before writing and applies it after its own updates. G2304 must exactly match either the recorded original or the corrected entry; unexpected wording fails rather than being silently replaced. Reimporting the original EV package must also run the guarded correction.

## Delivery state

Applied to the maintenance and primary local workspaces of both apps. Version remains 1.7.16. The owner subsequently authorized GitHub PRs, main merges and dev/prod web delivery. These are tracked in the delivery evidence; a source commit alone is not proof of deployment. No new tag, native rebuild or store upload is part of this correction.
