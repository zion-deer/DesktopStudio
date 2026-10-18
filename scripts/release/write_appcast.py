"""Write appcast.xml for one signed release archive. Does not see the private key."""

import os
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

from release_rules import parse_sign_update_output, upsert_appcast


def main() -> None:
    version = os.environ["MARKETING_VERSION"]
    build = os.environ["CURRENT_PROJECT_VERSION"]
    tag = os.environ["RELEASE_TAG"]
    repository = os.environ["GITHUB_REPOSITORY"]
    signature, length = parse_sign_update_output(
        pathlib.Path(os.environ["SIGN_OUTPUT_PATH"]).read_text(encoding="utf-8")
    )
    existing_path = os.environ.get("EXISTING_APPCAST", "")
    existing = None
    if existing_path and pathlib.Path(existing_path).is_file() and pathlib.Path(existing_path).stat().st_size:
        existing = pathlib.Path(existing_path).read_text(encoding="utf-8")
    url = f"https://github.com/{repository}/releases/download/{tag}/DesktopStudio-{version}.zip"
    xml = upsert_appcast(
        existing,
        short_version=version,
        build=build,
        enclosure_url=url,
        ed_signature=signature,
        length=length,
        title=f"Version {version}",
        published_at=__import__("time").time(),
    )
    output = pathlib.Path(os.environ["APPCAST_OUTPUT"])
    output.write_text(xml, encoding="utf-8")
    print(f"Wrote {output} for {url}")


if __name__ == "__main__":
    main()
