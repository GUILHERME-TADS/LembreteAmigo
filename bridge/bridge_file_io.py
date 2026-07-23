import argparse
import base64
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("operation", choices=("write", "append", "exists"))
    parser.add_argument("path")
    parser.add_argument("payload", nargs="?", default="")
    args = parser.parse_args()

    target = Path(args.path)
    if args.operation == "exists":
        print("true" if target.exists() else "false")
        return

    target.parent.mkdir(parents=True, exist_ok=True)
    data = base64.b64decode(args.payload.encode("ascii"))
    mode = "wb" if args.operation == "write" else "ab"
    with target.open(mode) as handle:
        handle.write(data)


if __name__ == "__main__":
    main()
