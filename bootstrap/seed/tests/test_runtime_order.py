import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location("runtime_order", Path(__file__).parents[1] / "runtime-order.py")
runtime_order = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runtime_order)


def item(name, *deps):
    return {"metadata": {"name": name}, "spec": {"dependsOn": [{"name": dep} for dep in deps]}}


class RuntimeOrderTest(unittest.TestCase):
    def test_orders_dependencies_first_and_ignores_other_stages(self):
        items = [
            item("assembly-us-east1-sandbox"),
            item("runtime-us-east1-b-sandbox", "assembly-us-east1-sandbox"),
            item("istio-us-east1-b-sandbox", "runtime-us-east1-b-sandbox", "istio-global-sandbox"),
            item("authentik-config-sandbox", "istio-us-east1-b-sandbox", "authentik-global-sandbox"),
            item("openbao-config-sandbox", "authentik-config-sandbox"),
            item("istio-us-east1-b-non-production"),
        ]

        self.assertEqual(
            runtime_order.tiers(items, "sandbox"),
            [
                ["runtime-us-east1-b-sandbox"],
                ["istio-us-east1-b-sandbox"],
                ["authentik-config-sandbox"],
                ["openbao-config-sandbox"],
            ],
        )

    def test_rejects_cycles(self):
        items = [item("istio-us-east1-b-sandbox", "mesh-us-east1-b-sandbox"), item("mesh-us-east1-b-sandbox", "istio-us-east1-b-sandbox")]
        with self.assertRaises(SystemExit):
            runtime_order.tiers(items, "sandbox")


if __name__ == "__main__":
    unittest.main()
