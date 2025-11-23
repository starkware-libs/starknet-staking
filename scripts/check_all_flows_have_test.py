#! /usr/bin/env python3

from io import BufferedReader
from re import search
from argparse import ArgumentParser, Namespace
from pathlib import Path
from collections import Counter
from pprint import pprint

CONTRACTS_FOLDER: Path = (
    Path(__file__).parent.parent
)

FLOWS_FILE: Path = CONTRACTS_FOLDER / "src/flow_test/flows.cairo"

TEST_FILES: list[Path] = [
    CONTRACTS_FOLDER / "src/flow_test/test.cairo",
    CONTRACTS_FOLDER / "src/flow_test/fork_test.cairo",
    CONTRACTS_FOLDER / "src/flow_test/multi_version_tests.cairo",
]


def parse_args() -> Namespace:
    parser = ArgumentParser()
    parser.add_argument(
        "--flows-file",
        type=str,
        help="The flows file to check the tests against.",
        default=FLOWS_FILE,
    )
    parser.add_argument(
        "--test-files",
        type=str,
        action="extend",
        nargs="+",
        help="All test files that test flows.",
        default=TEST_FILES,
    )
    parser.add_argument(
        "--allow-duplicate-tests",
        action="store_true",
        help="Don't fail if a flow is called more than once in the test files.",
    )
    parser.add_argument(
        "--allow-commented-tests",
        action="store_true",
        help="Don't fail if a flow is in a commented test.",
    )
    return parser.parse_args()


def get_flows(f: BufferedReader) -> list[str]:
    flows = []
    for line in f:
        res = search(r"struct ([^\s]+)", line)
        if res:
            flows.append(res.group(1))
    return flows


def count_tests(f: BufferedReader) -> tuple[Counter, list[str]]:
    test_counter = Counter()
    commented_tests = []
    for line in f:
        res = search(r"flows::([^\s]+)", line)
        if res:
            flow_name = res.group(1)
            test_counter[flow_name] += 1
            if line.startswith("//"):
                commented_tests.append(flow_name)
    return test_counter, commented_tests


def main() -> None:
    args = parse_args()
    flows_file = Path(args.flows_file)
    test_files = set([Path(test_file).absolute() for test_file in args.test_files])

    with open(flows_file, "r") as f:
        flows = get_flows(f)

    tested_flows = Counter()
    commented_flows = []
    for test_file in test_files:
        with open(test_file, "r") as f:
            tested_in_file, commented_in_file = count_tests(f)
            tested_flows += tested_in_file
            commented_flows += commented_in_file

    duplicate_tests = [flow for flow, count in tested_flows.items() if count > 1]
    if duplicate_tests:
        print("Flows called more than once:")
        pprint(duplicate_tests)

    not_tested = set(flows) - set(tested_flows.keys())
    if not_tested:
        print("Flows not tested:")
        pprint(not_tested)

    if commented_flows:
        print("Flows in commented tests:")
        pprint(commented_flows)

    if (
        not_tested
        or (not args.allow_duplicate_tests and duplicate_tests)
        or (not args.allow_commented_tests and commented_flows)
    ):
        exit(1)


if __name__ == "__main__":
    main()
