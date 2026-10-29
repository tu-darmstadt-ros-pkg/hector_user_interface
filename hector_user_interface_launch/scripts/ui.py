#!/usr/bin/env python3
"""Launch the Hector user interface (RViz), optionally inside a robot namespace."""

import argparse
import os
import re
import sys

from tuda_workspace_scripts.print import print_error, print_info

try:
    from ament_index_python.packages import get_package_share_directory
except ImportError:
    print_error(
        "ament_index_python is not available. Make sure ROS 2 is properly sourced."
    )
    sys.exit(1)


# A ROS 2 namespace is an (optionally absolute) sequence of name tokens separated by
# '/'. Each token starts with a letter or underscore and otherwise contains only
# alphanumerics or underscores - notably no hyphens.
NAMESPACE_RE = re.compile(r"^/?[A-Za-z_]\w*(/[A-Za-z_]\w*)*$")

# rviz configs that are not robot namespaces: 'default' is the global UI and
# 'single_robot' is the generic fallback config.
NON_NAMESPACE_CONFIGS = {"default", "single_robot"}


def _rviz_dir():
    """Directory holding the packaged rviz configs."""
    return os.path.join(
        get_package_share_directory("hector_user_interface_launch"), "rviz"
    )


def config_completer(**kwargs):
    """Suggest all rviz configs (extension stripped) that the UI can launch."""
    try:
        return [f[: -len(".rviz")] for f in os.listdir(_rviz_dir()) if f.endswith(".rviz")]
    except Exception:
        return []


def _ns_matches_config(ns, config):
    """Whether a live first-level namespace belongs to the named robot config.

    Matches the config exactly or a suffixed variant ('athena' -> '/athena',
    '/athena_sim', '/athena_postproc'), but not an unrelated name that merely shares
    a prefix ('athena' does not match '/athenax').
    """
    seg = ns.lstrip("/")
    return seg == config or seg.startswith(config + "_")


def _graph_first_level_namespaces():
    """First-level namespaces present in the live ROS graph (e.g. '/athena').

    Returns an empty set when ROS is unavailable or nothing is announced.
    """
    try:
        from types import SimpleNamespace

        from ros2cli.node.daemon import is_daemon_running
        from ros2cli.node.strategy import NodeStrategy
    except Exception:
        return set()
    try:
        # Use the daemon if it is already up (fast); otherwise a direct node - never
        # spawn a daemon as a TAB side effect.
        args = SimpleNamespace(spin_time=0.5, use_sim_time=False)
        args.no_daemon = not is_daemon_running(args)
        with NodeStrategy(args) as node:
            node_ns = [ns for _, ns in node.get_node_names_and_namespaces()]
            topics = [t for t, _ in node.get_topic_names_and_types()]
        first = set()
        # A node's namespace is authoritative: a node living in '/athena' means
        # athena is a namespace even if it is a single segment.
        for ns in node_ns:
            token = ns.lstrip("/").split("/")[0]
            if token:
                first.add("/" + token)
        # A topic only implies a namespace when it is nested (more than one segment);
        # root-level topics like '/rosout' or '/clock' are not namespaces.
        for t in topics:
            parts = t.lstrip("/").split("/")
            if len(parts) > 1 and parts[0]:
                first.add("/" + parts[0])
        return first
    except Exception:
        return set()


def namespace_completer(prefix, parsed_args, **kwargs):
    """Suggest namespaces like ros2: first-level namespaces from the live graph.

    Falls back to names derived from the already-typed config arg when the graph
    is empty (no ROS running).
    """
    names = _graph_first_level_namespaces()
    if not names:
        config = getattr(parsed_args, "config", None)
        if config and config not in NON_NAMESPACE_CONFIGS:
            names = {f"/{config}", f"/{config}_sim", f"/{config}_postproc"}
    return sorted(names)


def launch_ui(launch_args=None):
    """Replace this process with `ros2 launch` of the default UI.

    launch_args: optional iterable of "name:=value" strings forwarded to the launch.
    """
    launch_cmd = [
        "ros2",
        "launch",
        "hector_user_interface_launch",
        "default.launch.yaml",
        *(launch_args or []),
    ]

    print_info(f"Command: {' '.join(launch_cmd)}")

    # Replace this process with ros2 launch so Ctrl-C reaches it directly for a
    # clean shutdown and its exit code propagates without an extra wrapper.
    # Flush first because execvp does not flush Python's stdio buffers.
    sys.stdout.flush()
    try:
        os.execvp(launch_cmd[0], launch_cmd)
    except FileNotFoundError:
        print_error("ros2 command not found. Make sure ROS 2 is properly sourced.")
        sys.exit(1)


if __name__ == "__main__":
    prefix = os.environ.get("TUDA_WSS_PREFIX", "tuda_wss")
    parser = argparse.ArgumentParser(
        prog=f"{prefix} ui",
        description="Launch the Hector user interface (RViz)",
        epilog=(
            "Pass a ROS namespace to launch the UI inside it: rviz then reads the "
            "robot's tf and data under that namespace, so frames appear unprefixed. "
            "Without a namespace the UI starts globally and discovers all announced robots."
        ),
    )

    parser.add_argument(
        "config",
        nargs="?",
        default=None,
        help="rviz config to launch (extension stripped), e.g. athena. "
        "Defaults to the global 'default' config.",
    ).completer = config_completer

    parser.add_argument(
        "namespace",
        nargs="?",
        default=None,
        help="ROS namespace to launch in (e.g. athena). Defaults to the config "
        "name for robot configs; global otherwise.",
    ).completer = namespace_completer  # ros2-style: first-level namespaces from the live graph.

    try:
        import argcomplete

        argcomplete.autocomplete(parser)
    except ImportError:
        pass

    args = parser.parse_args()

    rviz_dir = _rviz_dir()

    # Pick the rviz config: <config>.rviz if it exists, else the generic single_robot
    # config. None lets the launch use its built-in default.rviz.
    if args.config is None:
        rviz_config = None
    else:
        named_path = os.path.join(rviz_dir, f"{args.config}.rviz")
        if os.path.isfile(named_path):
            rviz_config = named_path
        else:
            rviz_config = os.path.join(rviz_dir, "single_robot.rviz")

    # Pick the namespace
    if args.namespace is not None:
        namespace = args.namespace
    elif args.config in (None, "default"):
        # Bare `ui` or `ui default`: the global UI that discovers all robots.
        namespace = None
    else:
        is_robot_config = args.config not in NON_NAMESPACE_CONFIGS
        available = sorted(_graph_first_level_namespaces())
        # When a specific robot config is named, only consider namespaces for it (the
        # config itself or a suffixed variant like athena_sim/athena_postproc) so e.g.
        # `ui athena` ignores an unrelated /ec_scout. More than one athena-family
        # namespace being live is ambiguous (warn+exit).
        if is_robot_config:
            available = [ns for ns in available if _ns_matches_config(ns, args.config)]
        if len(available) == 1:
            namespace = available[0]
            print_info(f"Auto-selected the only live namespace: {namespace}")
        elif len(available) > 1:
            print_error("Multiple namespaces are live; specify one explicitly:")
            print_info("  " + "  ".join(available), file=sys.stderr)
            sys.exit(1)
        elif is_robot_config:
            namespace = args.config  # nothing live under it - use the config name
        else:
            namespace = None

    if namespace is not None:
        if not NAMESPACE_RE.match(namespace):
            print_error(f"'{namespace}' is not a valid ROS namespace")
            print_info(
                "Use letters, digits and underscores only (no hyphens); "
                f"e.g. '{namespace.replace('-', '_')}'",
                file=sys.stderr,
            )
            sys.exit(1)
        namespace = namespace.lstrip("/")

    launch_args = []
    if namespace:
        launch_args.append(f"robot_namespace:={namespace}")
    if rviz_config:
        launch_args.append(f"rviz_config:={rviz_config}")

    if namespace:
        print_info(f"Launching Hector UI in namespace: {namespace}")
    else:
        print_info("Launching Hector UI (global; discovers all announced robots)")
    launch_ui(launch_args)
