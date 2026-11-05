# Technical risks and owner decisions

1. `TraversalOutdoorNegativeBegin` searches for an existing closed Door within48m; it was absent in018. Larger search radius is not proof, may just waste startup time. Preferred is genuine paid native wall/door fixture in isolated world with independently measured site and no fake collider.
2. Current `ProbeDisplacement` calls `Block` for normal read-only refusal; negative observation may make later tests impossible. Pure read-only refusal must not relax command collision admission. Under pending/active motion, read-only probe should refuse execution rather than change body.
3. A sealed room with a closed door cannot be bypassed by walking through a wall. Detour should go around a finite exterior wall, not through the inside of a sealed home. Name and prove target collider for wall and door separately.
4. Native placement may be blocked by terrain/socket/safety and high site requirements. Capture `CanBuild`, previews and reasons; no free prefabs or terrain edits. Minimal paid wall/door allowed G4 only; full eight-role house required G5.
5. The doorway threshold in earlier014/016 produced real body overlaps. 018 slope movement is not proof of **discrete** step. Don't ignore foundation/doorway or change body to claim G5. Report unsafe honest partial.
6. Performance of 50–100 bots not demonstrated by one 11.8m NPC; future proximity-driven sensor updates and LOD required. Keep per-tick budgets now.
7. Later gameplay wishlist: crouch/crouch-walk, jump/land/vault, native monuments with local-coordinate route templates and green-blue-red keycards/fuses/real loot, Bradley HV combat, patrol helicopter fire/wait/crates, base storage/research/respawn, group raids and Excavator. These aren't in019.
8. Significant design choices outside approved controller C must be explained to owner with tradeoffs and recommended choice before implementation. Routine technical fixes do not warrant questions.
