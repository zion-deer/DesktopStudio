"""Release version and appcast rules for Desktop Studio.

The private Sparkle key never enters this module. Signing stays in the release workflow.
"""

from __future__ import annotations

import base64
import re
import xml.etree.ElementTree as ET
from email.utils import formatdate

SPARKLE = "http://www.andymatuschak.org/xml-namespaces/sparkle"
DC = "http://purl.org/dc/elements/1.1/"
APPCAST_NAME = "appcast.xml"
MINIMUM_SYSTEM_VERSION = "14.0"

ET.register_namespace("sparkle", SPARKLE)
ET.register_namespace("dc", DC)


class ReleaseValidationError(Exception):
    pass


def is_semantic_version(value: str) -> bool:
    parts = value.split(".")
    if len(parts) != 3:
        return False
    return all(_unpadded_number(part) for part in parts)


def marketing_version_from_tag(tag: str) -> str:
    if not tag.startswith("v"):
        raise ReleaseValidationError("The release tag must look like v0.2.0.")
    version = tag[1:]
    if not is_semantic_version(version):
        raise ReleaseValidationError(f"The tag {tag} is not a semantic version.")
    return version


def is_build_number(value: str) -> bool:
    return _unpadded_number(value)


def assert_build_is_newer(candidate: str, previous: list[str]) -> None:
    if not is_build_number(candidate):
        raise ReleaseValidationError("CURRENT_PROJECT_VERSION must be a positive integer without a leading zero.")
    candidate_number = int(candidate)
    for earlier in previous:
        if not is_build_number(earlier):
            raise ReleaseValidationError(f"A previous release build number is invalid: {earlier}")
        if candidate_number <= int(earlier):
            raise ReleaseValidationError(
                f"Build {candidate} does not increase past the already published build {earlier}."
            )


def read_project_versions(pbxproj: str) -> tuple[str, str]:
    marketing = set(re.findall(r"MARKETING_VERSION = ([^;]+);", pbxproj))
    builds = set(re.findall(r"CURRENT_PROJECT_VERSION = ([^;]+);", pbxproj))
    if len(marketing) != 1 or len(builds) != 1:
        raise ReleaseValidationError("MARKETING_VERSION and CURRENT_PROJECT_VERSION must each have one value.")
    version = marketing.pop()
    build = builds.pop()
    if not is_semantic_version(version):
        raise ReleaseValidationError(f"MARKETING_VERSION {version} is not a semantic version.")
    if not is_build_number(build):
        raise ReleaseValidationError(f"CURRENT_PROJECT_VERSION {build} is not a build number.")
    return version, build


def assert_app_version_constants(swift_source: str, version: str, build: str) -> None:
    if f'establishedMarketingVersion = "{version}"' not in swift_source:
        raise ReleaseValidationError("AppVersion.establishedMarketingVersion does not match MARKETING_VERSION.")
    if f'establishedBuildNumber = "{build}"' not in swift_source:
        raise ReleaseValidationError("AppVersion.establishedBuildNumber does not match CURRENT_PROJECT_VERSION.")


def assert_tag_matches_project(tag: str, version: str) -> None:
    tagged = marketing_version_from_tag(tag)
    if tagged != version:
        raise ReleaseValidationError(
            f"Tag {tag} does not match MARKETING_VERSION {version}. The release was not published."
        )


def assert_feed_url(url: str) -> None:
    lowered = url.lower()
    if not url.startswith("https://") or url.endswith(" ") or " " in url:
        raise ReleaseValidationError("DESKTOP_STUDIO_UPDATE_FEED_URL must be an https URL.")
    for banned in ("example.com", "example.org", "yourcompany", "placeholder", "changeme", "<owner>", "<repo>"):
        if banned in lowered or banned in url:
            raise ReleaseValidationError("DESKTOP_STUDIO_UPDATE_FEED_URL is still a placeholder.")
    if "@" in url.split("://", 1)[1].split("/", 1)[0]:
        raise ReleaseValidationError("The feed URL must not contain credentials.")
    if not url.split("?", 1)[0].rstrip("/").endswith("/" + APPCAST_NAME) and not url.endswith(APPCAST_NAME):
        raise ReleaseValidationError("The feed URL must end with appcast.xml.")


def assert_public_key(value: str) -> None:
    try:
        decoded = base64.b64decode(value, validate=True)
    except Exception as error:
        raise ReleaseValidationError("DESKTOP_STUDIO_SPARKLE_PUBLIC_KEY is not base64.") from error
    if len(decoded) != 32:
        raise ReleaseValidationError("DESKTOP_STUDIO_SPARKLE_PUBLIC_KEY must decode to 32 bytes.")


def enclosure_error(url: str, short_version: str, signature: str, length: int) -> str | None:
    if not url.startswith("https://"):
        return "The update archive URL must be https."
    parts = [part for part in url.split("?", 1)[0].split("/") if part]
    if "latest" in parts:
        return "The update archive URL must not use a mutable latest download link."
    if "download" not in parts:
        return "The update archive URL must be a GitHub release download."
    download = parts.index("download")
    if download + 1 >= len(parts) or parts[download + 1] != f"v{short_version}":
        return f"The update archive URL must include /releases/download/v{short_version}/."
    if not url.split("?", 1)[0].endswith(".zip"):
        return "The update archive must be a zip."
    try:
        base64.b64decode(signature, validate=True)
    except Exception:
        return "The update archive is missing a Sparkle EdDSA signature."
    if not signature:
        return "The update archive is missing a Sparkle EdDSA signature."
    if length <= 0:
        return "The update archive length must be greater than zero."
    return None


def upsert_appcast(
    existing_xml: str | None,
    *,
    short_version: str,
    build: str,
    enclosure_url: str,
    ed_signature: str,
    length: int,
    title: str,
    published_at: float,
) -> str:
    problem = enclosure_error(enclosure_url, short_version, ed_signature, length)
    if problem:
        raise ReleaseValidationError(problem)
    if not is_semantic_version(short_version) or not is_build_number(build):
        raise ReleaseValidationError("The appcast item version is invalid.")

    if existing_xml:
        root = ET.fromstring(existing_xml)
    else:
        root = ET.Element("rss", {"version": "2.0"})
        channel = ET.SubElement(root, "channel")
        ET.SubElement(channel, "title").text = "Desktop Studio"
        ET.SubElement(channel, "language").text = "en"
    channel = root.find("channel")
    if channel is None:
        raise ReleaseValidationError("The existing appcast has no channel.")

    for item in channel.findall("item"):
        existing_build = _text(item, f"{{{SPARKLE}}}version")
        existing_short = _text(item, f"{{{SPARKLE}}}shortVersionString")
        if existing_build == build or existing_short == short_version:
            raise ReleaseValidationError(
                f"The appcast already contains version {existing_short} build {existing_build}."
            )

    item = ET.Element("item")
    ET.SubElement(item, "title").text = title
    ET.SubElement(item, "pubDate").text = formatdate(published_at, usegmt=True)
    ET.SubElement(item, f"{{{SPARKLE}}}version").text = build
    ET.SubElement(item, f"{{{SPARKLE}}}shortVersionString").text = short_version
    ET.SubElement(item, f"{{{SPARKLE}}}minimumSystemVersion").text = MINIMUM_SYSTEM_VERSION
    enclosure = ET.SubElement(item, "enclosure")
    enclosure.set("url", enclosure_url)
    enclosure.set(f"{{{SPARKLE}}}edSignature", ed_signature)
    enclosure.set("length", str(length))
    enclosure.set("type", "application/octet-stream")
    channel.insert(0, item)
    return ET.tostring(root, encoding="utf-8", xml_declaration=True).decode("utf-8")


def parse_sign_update_output(output: str) -> tuple[str, int]:
    signature = re.search(r'sparkle:edSignature="([^"]+)"', output)
    length = re.search(r'length="(\d+)"', output)
    if signature is None or length is None:
        raise ReleaseValidationError("sign_update did not return an EdDSA signature and length.")
    return signature.group(1), int(length.group(1))


def _text(item: ET.Element, tag: str) -> str:
    node = item.find(tag)
    return (node.text or "").strip() if node is not None else ""


def _unpadded_number(value: str) -> bool:
    return bool(value) and value.isdigit() and (len(value) == 1 or not value.startswith("0"))
