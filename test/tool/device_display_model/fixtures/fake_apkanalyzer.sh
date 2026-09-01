#!/usr/bin/env bash

set -euo pipefail

apk_path="${@: -1}"
source_hash="$(head -n 1 "$apk_path")"

printf '.class public final Ldev/ventairy/oh_my_flutter/device_display_model_collector/BuildConfig;\n'
printf '.super Ljava/lang/Object;\n'
printf '.source "BuildConfig.java"\n\n'
printf '# static fields\n'
printf '.field public static final COLLECTOR_SOURCE_HASH:Ljava/lang/String; = "%s"\n' "$source_hash"
