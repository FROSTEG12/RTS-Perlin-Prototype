Upstream: https://github.com/Rytelier/Godot-Color-Grading (MIT).
Dependency: Rytelier/Godot-compositor-effect-kit, commit
882222cc089bdd5dad4aa6a53e54f4d2e2432815 (license in Compositor/General).

Local integration: shader UID references in ColorGrading.gd replaced with
explicit resource paths for portable imports. No changes to the grading math.
Removed redundant signal disconnection during PREDELETE in the base class:
Godot disconnects freed receivers automatically; binding here caused an error.
WorldEnvironment runs ColorGrading only; LocalContrast and night noise are off.
The UI checkbox disables the compositor effect completely for A/B comparison.
