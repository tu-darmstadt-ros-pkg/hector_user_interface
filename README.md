# Hector User Interface

**Maintainer:** Stefan Fabian

This is the hector user interface.  
The third generation of the Team Hector rviz-based user interface.

## Quickstart

To integrate your robot with this interface, follow the instructions in [ROBOT_SETUP](ROBOT_SETUP.md).

## Style

The resources and styles / colors used are defined in hector_user_interface_resources for consistent styling.
You can import the Style singleton using

```qml
import Hector.Style 1.0
```

## Internal controls

The hector_internal_qml_controls package contains QML components used only internally by Team Hector because they depend on our styling or are strongly dependant on our software architecture.
They can be imported using

```qml
import Hector.InternalControls 1.0
```

For controls, that can be used with little to no adaptation necessary have a look at the [`hector_qml_controls` repo](https://github.com/tu-darmstadt-ros-pkg/hector_qml_controls).

## Contributing

rviz rewrites volatile UI-state on every save (window geometry, camera pose, panel layout,
auto-computed bounds) and accumulates runtime content (e.g. per-robot namespaces under a
MultiRobotModel display), which causes noisy diffs and merge conflicts. Before committing
changes to an rviz config, run `tools/clean_rviz_configs.sh`: it resets volatile keys to their committed
value (keeping the key, dropping local drift) and strips dynamic content, while leaving your real
edits untouched. The `rviz-no-volatile` pre-commit hook rejects a commit that still contains such
state (override a deliberate change with `git commit --no-verify`). The rules live in
`tools/rviz_blacklist.txt`, which documents the selector grammar.
