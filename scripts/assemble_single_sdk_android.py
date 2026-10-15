#!/usr/bin/env python3
"""Generate one Android plugin from the existing internal plugin implementations.

This does not change the monorepo's original modules.  Run the Dart candidate
assembler first; the result remains an UNPUBLISHABLE engineering artifact until
independent Android build/device checks and other platforms pass.
"""

import json
import re
import shutil
import xml.etree.ElementTree as ET
from pathlib import Path

from audit_single_pub_package import ROOT, plugin_entrypoints

OUT = ROOT / "build" / "single_sdk_candidate"
ANDROID_NS = "http://schemas.android.com/apk/res/android"
ET.register_namespace("android", ANDROID_NS)
ANDROID_NAME = f"{{{ANDROID_NS}}}name"


def merge_android_manifest(names: list[str], target: Path) -> None:
    result = ET.Element("manifest")
    app = ET.SubElement(result, "application")
    seen: dict[tuple[str, str], str] = {}
    for name in names:
        source = ROOT / "packages" / name / "android" / "src" / "main" / "AndroidManifest.xml"
        if not source.exists():
            continue
        root = ET.parse(source).getroot()
        java_package = plugin_entrypoints((ROOT / "packages" / name / "pubspec.yaml").read_text()).get("android", {}).get("package", "")
        base = root.get("package", java_package)
        for elem in root:
            if elem.tag == "application":
                children = elem
                parent = app
            else:
                children = [elem]
                parent = result
            for child in children:
                # Android's ".Service" shorthand is relative to its former
                # plugin manifest package and must be fully qualified.
                raw = child.get(ANDROID_NAME, "")
                if raw.startswith("."):
                    child.set(ANDROID_NAME, base + raw)
                key = (child.tag, child.get(ANDROID_NAME, ""))
                # Tail indentation belongs to the surrounding manifest,
                # not the element's meaning: compare semantic XML instead.
                def semantic(element):
                    return (element.tag, tuple(sorted(element.attrib.items())),
                            (element.text or "").strip(),
                            tuple(semantic(c) for c in element))
                encoded = semantic(child)
                if key in seen:
                    if seen[key] != encoded:
                        raise ValueError(f"Conflicting AndroidManifest entry {key} from {name}")
                    continue
                seen[key] = encoded
                parent.append(child)
    ET.ElementTree(result).write(target, encoding="utf-8", xml_declaration=True)


def merge_source_files(names: list[str], dst: Path) -> int:
    count = 0
    for name in names:
        source = ROOT / "packages" / name / "android" / "src" / "main"
        if not source.exists():
            continue
        for item in source.rglob("*"):
            if not item.is_file() or item.name == "AndroidManifest.xml":
                continue
            relative = item.relative_to(source)
            output = dst / relative
            output.parent.mkdir(parents=True, exist_ok=True)
            if output.exists():
                if output.read_bytes() != item.read_bytes():
                    raise ValueError(f"Native filename collision at {relative}: {name}")
                continue
            shutil.copy2(item, output)
            count += 1
    return count


def android_dependencies(names: list[str]) -> list[str]:
    dependencies: set[tuple[str, str]] = set()
    for name in names:
        src = ROOT / "packages" / name / "android"
        for filename in ("build.gradle", "build.gradle.kts"):
            file = src / filename
            if not file.exists():
                continue
            content = file.read_text()
            for kind, notation in re.findall(
                r"(?m)^\s*(implementation|compileOnly|api|runtimeOnly)\s*\(?\s*['\"]([^'\"]+)['\"]",
                content,
            ):
                dependencies.add((kind, notation))
            for module in re.findall(
                r"(?m)^\s*(implementation|api|compileOnly)\s*(?:\(\s*)?project\(\s*['\"]:(\w+)['\"]\s*\)",
                content,
            ):
                if module[1] not in names:
                    dependencies.add((module[0], f"project(':{module[1]}')"))
    # IVS uses a classified AAR. The artifact transform in this module
    # removes duplicated jni_zero annotations from the embedded WebRTC jar.
    dependencies.discard(("api", "com.amazonaws:ivs-broadcast:1.47.0"))
    return [
        f"    {kind} {notation}" if notation.startswith("project(")
        else f"    {kind} '{notation}'"
        for kind, notation in sorted(dependencies)
    ]


def generate_registrar(names: list[str], dst: Path) -> None:
    specs = [
        plugin_entrypoints((ROOT / "packages" / name / "pubspec.yaml").read_text())["android"]
        for name in names
    ]
    classes = [f"{s['package']}.{s['pluginClass']}" for s in specs]
    source = """package com.oneplusdream.flutter_realtime_sdk;

import androidx.annotation.NonNull;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import java.util.ArrayList;
import java.util.List;

/** Single-plugin registrar preserving existing vendor channel namespaces. */
public final class FlutterRealtimeSdkPlugin implements FlutterPlugin, ActivityAware {
  private final List<FlutterPlugin> children = new ArrayList<>();
  @Override public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
"""
    source += "".join(f"    children.add(new {c}());\n" for c in classes)
    source += """    for (FlutterPlugin plugin : children) plugin.onAttachedToEngine(binding);
  }
  @Override public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    for (int i = children.size() - 1; i >= 0; i--) {
      children.get(i).onDetachedFromEngine(binding);
    }
    children.clear();
  }
  @Override public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    for (FlutterPlugin plugin : children)
      if (plugin instanceof ActivityAware) ((ActivityAware) plugin).onAttachedToActivity(binding);
  }
  @Override public void onDetachedFromActivityForConfigChanges() {
    for (FlutterPlugin plugin : children)
      if (plugin instanceof ActivityAware) ((ActivityAware) plugin).onDetachedFromActivityForConfigChanges();
  }
  @Override public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
    for (FlutterPlugin plugin : children)
      if (plugin instanceof ActivityAware) ((ActivityAware) plugin).onReattachedToActivityForConfigChanges(binding);
  }
  @Override public void onDetachedFromActivity() {
    for (FlutterPlugin plugin : children)
      if (plugin instanceof ActivityAware) ((ActivityAware) plugin).onDetachedFromActivity();
  }
}
"""
    p = dst / "java" / "com" / "oneplusdream" / "flutter_realtime_sdk" / "FlutterRealtimeSdkPlugin.java"
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(source)


def run() -> dict:
    if not (OUT / "pubspec.yaml").exists():
        raise ValueError("Run assemble_single_sdk_candidate.py first.")
    names = json.loads((ROOT / "scripts" / "sdk_packages.json").read_text())
    native = [
        n for n in names
        if "android" in plugin_entrypoints((ROOT / "packages" / n / "pubspec.yaml").read_text())
    ]
    src = OUT / "android" / "src" / "main"
    if src.exists():
        shutil.rmtree(src)
    src.mkdir(parents=True, exist_ok=True)
    count = merge_source_files(native, src)
    merge_android_manifest(native, src / "AndroidManifest.xml")
    generate_registrar(native, src)
    ivs = (ROOT / "packages" / "flutter_realtime_media_ivs" / "android" / "build.gradle").read_text()
    transform_header = ivs.split("group 'com.oneplusdream", 1)[0]
    # Both Agora RTC and Hyphenate Chat bring libaosl.so, but with different
    # bytes. A generic app-level pickFirst masks ABI incompatibilities and
    # forces every SDK consumer to alter its Gradle file. Retain the canonical
    # io.agora.infra:aosl dependency and strip the embedded duplicate from
    # the Hyphenate Chat AAR during the existing Android artifact transform.
    former = "if (!input.name.startsWith('ivs-broadcast-')) {"
    combined = "if (!input.name.startsWith('ivs-broadcast-') &&\n            !input.name.startsWith('hyphenate-chat-')) {"
    if transform_header.count(former) != 1:
        raise ValueError("IVS Gradle artifact transformer changed; review required")
    transform_header = transform_header.replace(former, combined)
    original_entry = "while ((entry = source.nextEntry) != null) {\n            def replacement = new ZipEntry(entry.name)"
    stripped_entry = """while ((entry = source.nextEntry) != null) {
            if (input.name.startsWith('hyphenate-chat-') &&
                entry.name ==~ /jni\\/[^\\/]+\\/libaosl\\.so/) {
                source.closeEntry()
                continue
            }
            def replacement = new ZipEntry(entry.name)"""
    if transform_header.count(original_entry) != 1:
        raise ValueError("IVS artifact transform body changed; review required")
    transform_header = transform_header.replace(original_entry, stripped_entry)
    transform_config = ivs.split("def ivsJniCompatible", 1)[1].split("dependencies {", 1)[0]
    gradle = transform_header + """
group 'com.oneplusdream.flutter_realtime_sdk'
version '0.1.0'
apply plugin: 'com.android.library'

repositories {
  google()
  mavenCentral()
  // Alibaba ARTC is distributed from Alibaba's own Maven repositories.
  maven {
    url 'https://maven.aliyun.com/repository/google'
    content { includeGroup 'com.aliyun.aio'; includeGroup 'com.aliyun.aio.keep' }
  }
  maven {
    url 'https://maven.aliyun.com/repository/public'
    content { includeGroup 'com.aliyun.aio'; includeGroup 'com.aliyun.aio.keep' }
  }
}

android {
  namespace 'com.oneplusdream.flutter_realtime_sdk'
  compileSdk 37
  ndkVersion '28.2.13676358'
  defaultConfig {
    minSdk 28
    consumerProguardFiles 'consumer-rules.pro'
  }
  compileOptions {
    sourceCompatibility JavaVersion.VERSION_17
    targetCompatibility JavaVersion.VERSION_17
  }
  sourceSets { main.java.srcDirs += 'src/main/kotlin' }
}

kotlin {
  compilerOptions {
    jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
  }
}

def ivsJniCompatible""" + transform_config + """
dependencies {
""" + "\n".join(android_dependencies(native)) + """
    api('com.amazonaws:ivs-broadcast:1.47.0') {
        artifact { name = 'ivs-broadcast'; type = 'aar'; classifier = 'stages' }
    }
}
"""
    (OUT / "android" / "build.gradle").write_text(gradle)
    # Optional OEM push integrations in Hyphenate Chat are referenced but not
    # installed unless an app explicitly enables the relevant OEM push SDK.
    # Preserve R8 shrinking of our code and limit suppressions to missing
    # optional classes observed in the independent release-host build.
    (OUT / "android" / "consumer-rules.pro").write_text(
        "# Hyphenate optional vendor-specific push (not a runtime SDK dependency).\n"
        "-dontwarn com.heytap.msp.push.HeytapPushManager\n"
        "-dontwarn com.heytap.msp.push.callback.ICallBackResultService\n"
        "-dontwarn com.meizu.cloud.pushsdk.PushManager\n"
        "-dontwarn com.meizu.cloud.pushsdk.util.MzSystemUtils\n"
        "-dontwarn com.vivo.push.IPushActionListener\n"
        "-dontwarn com.vivo.push.PushClient\n"
        "-dontwarn com.vivo.push.PushConfig$Builder\n"
        "-dontwarn com.vivo.push.PushConfig\n"
        "-dontwarn com.vivo.push.util.VivoPushException\n"
        "-dontwarn com.xiaomi.mipush.sdk.MiPushClient\n"
    )
    manifest = OUT / "pubspec.yaml"
    content = manifest.read_text()
    anchor = "flutter:\n  uses-material-design: true\n"
    if anchor not in content:
        raise ValueError("Expected single-package candidate pubspec format changed")
    platform = "      android:\n        package: com.oneplusdream.flutter_realtime_sdk\n        pluginClass: FlutterRealtimeSdkPlugin\n"
    if platform not in content:
        if "  plugin:\n    platforms:\n" in content:
            content = content.replace("  plugin:\n    platforms:\n", "  plugin:\n    platforms:\n" + platform, 1)
        else:
            content = content.replace(anchor, anchor + "  plugin:\n    platforms:\n" + platform)
    manifest.write_text(content)
    return {"platform": "android", "registrations": len(native),
            "sourceFiles": count, "minimumSdk": 28,
            "warning": "Android compile and device tests still required"}


if __name__ == "__main__":
    print(json.dumps(run(), indent=2))
