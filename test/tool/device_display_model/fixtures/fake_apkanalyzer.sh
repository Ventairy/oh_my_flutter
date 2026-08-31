#!/bin/zsh

set -euo pipefail

apk_path="${@: -1}"
source_hash="$(head -n 1 "$apk_path")"

print '.class public final Ldev/ventairy/oh_my_flutter/device_display_model_collector/BuildConfig;'
print '.super Ljava/lang/Object;'
print '.source "BuildConfig.java"'
print
print '# static fields'
print ".field public static final COLLECTOR_SOURCE_HASH:Ljava/lang/String; = \"$source_hash\""
