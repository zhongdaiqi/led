#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
CI 专用：把只能在本地鸿蒙环境解析的依赖，转换成可在 GitHub ubuntu runner 上
正常 `flutter pub get` 的形式。仅作用于 CI 的临时 checkout，不触碰本地源码。

与 dingzhixia 的差异：led 只依赖一个第三方包 shared_preferences，但它是
**gitcode.com 的 git 依赖**（openharmony-tpc/flutter_packages 的 OHOS fork）。
GitHub runner 在国内源上拉取极不稳定（超时/中断），且该 fork 的 android 实现
与 pub.dev 官方版等价。因此这里把它换成 pub.dev hosted 的同版本 2.2.0。

转换内容：
  1. pubspec.yaml 里 `shared_preferences:` + `git:` 子块 -> `shared_preferences: 2.2.0`
  2. 删除 pubspec.lock —— lock 里记录了 `source: git` 与 resolved-ref，若不删，
     `flutter pub get` 会继续按 git 源解析，转换白做。
  3. 若存在 dependency_overrides 整段（可能含本地 path），一并删除。

注意：只应在 CI 上运行，不要在本地 Windows 开发机执行（会破坏 OHOS 依赖）。
"""
import os
import re
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)
PUBSPEC = os.path.join(REPO_ROOT, "pubspec.yaml")
PUBSPEC_LOCK = os.path.join(REPO_ROOT, "pubspec.lock")

# git/path 依赖 -> pub.dev hosted 同版本（同版本保证 CI 与本地行为一致）
HOSTED_PINNED = {
    "shared_preferences": "2.2.0",
}


def _next_nonblank(lines, start):
    j = start
    while j < len(lines) and lines[j].strip() == "":
        j += 1
    return j


def transform_pubspec() -> int:
    if not os.path.isfile(PUBSPEC):
        print("::error::找不到 %s" % PUBSPEC, file=sys.stderr)
        return 1

    lines = open(PUBSPEC, encoding="utf-8").read().split("\n")
    out = []
    i, n = 0, len(lines)
    pinned = 0
    removed_overrides = 0
    in_overrides = False

    while i < n:
        line = lines[i]
        stripped = line.strip()

        # 顶格的 dependency_overrides: 段整段删除（CI 上本地 path 不存在）
        if stripped == "dependency_overrides:" and not in_overrides:
            in_overrides = True
            i += 1
            continue
        if in_overrides:
            if line and not (line[0] in (" ", "\t")):
                in_overrides = False          # 段落结束，此行按正常处理
            else:
                removed_overrides += 1
                i += 1
                continue

        m = re.match(r"^(\s*)([A-Za-z0-9_]+):\s*$", line)
        if m:
            indent, name = m.group(1), m.group(2)
            if name in HOSTED_PINNED:
                j = _next_nonblank(lines, i + 1)
                if j < n and (lines[j].strip().startswith("git:")
                              or lines[j].strip().startswith("path:")):
                    # 跳过整个子块（缩进大于当前 key 的行）
                    k = j + 1
                    while k < n and (lines[k].strip() == ""
                                     or len(lines[k]) - len(lines[k].lstrip()) > len(indent)):
                        k += 1
                    out.append("%s%s: %s" % (indent, name, HOSTED_PINNED[name]))
                    pinned += 1
                    # 保留原 git 子块后的空行分隔（否则下一个顶层 key 会紧贴上一行）
                    if k < n and lines[k].strip() != "" and (not out or out[-1].strip() != ""):
                        out.append("")
                    i = k
                    continue

        out.append(line)
        i += 1

    open(PUBSPEC, "w", encoding="utf-8").write("\n".join(out))
    print("transform_pubspec_android: pinned_hosted=%d, removed_override_lines=%d"
          % (pinned, removed_overrides))
    if pinned == 0:
        print("::warning::未匹配到任何 git/path 依赖，pubspec 可能已是 hosted 形式")
    return 0


def drop_lock() -> int:
    if os.path.isfile(PUBSPEC_LOCK):
        os.remove(PUBSPEC_LOCK)
        print("drop_lock: removed pubspec.lock（强制按转换后的 pubspec 重新解析）")
    else:
        print("drop_lock: pubspec.lock 不存在，跳过")
    return 0


def main() -> int:
    rc = transform_pubspec()
    if rc != 0:
        return rc
    drop_lock()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
