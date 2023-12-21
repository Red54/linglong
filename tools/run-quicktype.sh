#!/bin/bash

# SPDX-FileCopyrightText: 2023 UnionTech Software Technology Co., Ltd.
#
# SPDX-License-Identifier: LGPL-3.0-or-later

set -e
set -o pipefail

GIT=${GIT:="git"}

repoRoot="$("$GIT" rev-parse --show-toplevel)"
cd "$repoRoot/tools"

git submodule update --init --depth 1

QUICKTYPE=${QUICKTYPE:=""}

if [ -z "$QUICKTYPE" ]; then
        pushd quicktype
        npm i
        npm run build
        popd
fi

quicktype() {
        if [ -z "$QUICKTYPE" ]; then
                pushd quicktype
                npx quicktype "$@"
                popd
        else
                exec $QUICKTYPE "$@"
        fi
}

generate() {
        schema="$1"
        shift
        toplevel_type="$1"
        shift
        namespace="$1"
        shift
        include="$1"
        shift
        output_path="$1"

        if [[ ! -f "$schema" ]]; then
                echo "$schema not found" || exit 255
        fi

        filename="/dev/null"

        while read -r line; do
                if [[ $line != //\ stdout &&
                        $line != //*.hpp &&
                        $line != \#include\ \"*\" ]]; then
                        echo "$line" >>"$filename"
                        continue
                fi

                if [[ $line == \#include\ \"*\" ]]; then
                        header=${line#\#include\ \"}
                        header=${header%\"}
                        printf "#include \"%s/%s\"\n" \
                                "$output_path" \
                                "$header" \
                                >>"$filename"
                        continue
                fi

                echo "// clang-format on" >>"$filename"

                filename="${repoRoot}/$include/$output_path/${line#\/\/ }"
                if [[ $line == //\ stdout ]]; then
                        filename="/dev/null"
                fi

                # echo "generating $filename"

                mkdir -p "$(dirname "$filename")"
                {
                        echo "// Thish file is generated by /tools/run-quicktype.sh"
                        echo "// DO NOT EDIT IT."
                        echo ""
                        echo "// clang-format off"
                } >"$filename"
        done < <(quicktype "$schema" \
                --lang c++ \
                -s schema \
                -t "$toplevel_type" \
                --namespace "$namespace" \
                --code-format with-struct \
                --source-style multi-source \
                --include-location global-include \
                --type-style pascal-case-upper-acronyms \
                --member-style camel-case-upper-acronyms \
                --enumerator-style pascal-case-upper-acronyms \
                --no-boost \
                --hide-null-optional)

        {
                echo ""
                echo "// clang-format on"
        } >>"$filename"
}

include="src/"

generate \
        "$repoRoot/api/JSON Schema/project.json" \
        Project \
        "linglong::builder::project" \
        "$include" \
        "linglong/builder/project"

generate \
        "$repoRoot/api/JSON Schema/ll-builder-config.json" \
        Config \
        "linglong::builder::config" \
        "$include" \
        "linglong/builder/config"

generate \
        "$repoRoot/api/JSON Schema/LayerInfo.json" \
        LayerInfo \
        "linglong::package::layer" \
        "$include" \
        "linglong/package/layer"

generate \
        "$repoRoot/api/JSON Schema/repo-config-v1.json" \
        ConfigV1 \
        "linglong::repo::config" \
        "$include" \
        "linglong/repo/config"
