#!/usr/bin/env python3
"""Order Runtime Floor objects for teardown and rebuild.

Reads `kubectl get terraform -o json` from stdin and prints one dependency tier per
line (space-separated object names). Tiers list dependencies first; runtime.sh
reverses them for `down`. Usage: runtime-order.py <environment>
"""

import json
import re
import sys

CONFIG_STAGES = ("authentik-config", "openbao-config")


def tiers(items, environment):
    zonal = re.compile(rf"-us-east[14]-[a-f]-{environment}$")
    names = {item["metadata"]["name"] for item in items}
    nodes = {
        name for name in names
        if zonal.search(name) or name in {f"{stage}-{environment}" for stage in CONFIG_STAGES}
    }
    deps = {
        item["metadata"]["name"]: {
            dep["name"] for dep in item["spec"].get("dependsOn", []) if dep["name"] in nodes
        }
        for item in items
        if item["metadata"]["name"] in nodes
    }

    result, done = [], set()
    while len(done) < len(nodes):
        tier = sorted(name for name in nodes - done if deps[name] <= done)
        if not tier:
            raise SystemExit("Dependency cycle among Runtime objects.")
        result.append(tier)
        done.update(tier)
    return result


if __name__ == "__main__":
    environment = sys.argv[1]
    for tier in tiers(json.load(sys.stdin)["items"], environment):
        print(" ".join(tier))
