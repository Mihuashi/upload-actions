## 简介

该 [GitHub Action](https://help.github.com/cn/actions) 用于上传 apk 文件到 VIVO 应用商店。

## workflow 示例

在目标仓库中创建 `.github/workflows/xxx.yml` 即可，文件名任意，配置参考如下：

```yaml
name: deploy

on:
  push:
    branches:
      - pgyer
      - pgyer-debug

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/cache@v4
        with:
          path: |
            ~/.gradle/caches
            ~/.gradle/wrapper
          key: ${{ runner.os }}-gradle-${{ hashFiles('**/*.gradle*', '**/gradle-wrapper.properties') }}
          restore-keys: |
            ${{ runner.os }}-gradle-

      - name: Checkout project
        uses: actions/checkout@v2

      - name: Setup JDK 11
        uses: actions/setup-java@v4
        with:
          distribution: corretto
          java-version: 11
          cache: gradle

      - uses: nttld/setup-ndk@v1
        id: setup-ndk
        with:
          ndk-version: r21e
          add-to-path: false
          local-cache: true

      - name: Write local.properties
        run: echo "ndk.dir=$ANDROID_NDK_HOME" >> local.properties
        env:
          ANDROID_NDK_HOME: ${{ steps.setup-ndk.outputs.ndk-path }}

      - name: Build app
        uses: burrunan/gradle-cache-action@v1
        with:
          arguments: ${{ github.ref_name == 'pgyer' && 'assembleRelease' || 'assembleDebug' }}
          gradle-version: wrapper

      - name: get version
        id: version
        run: |
          file_path="config.gradle"
          version_code=$(grep -oP 'VersionCode\s*:\s*\K\d+' "$file_path")
          version_name=$(grep -oP 'VersionName\s*:\s*"\K[^"]+' "$file_path")
          echo "version_code=$version_code" >> $GITHUB_OUTPUT
          echo "version_name=$version_name" >> $GITHUB_OUTPUT
          online_time=$(yq '.online_time' release.yml)
          update_desc=$(yq '.update_desc' release.yml)
          echo "online_time=$online_time" >> $GITHUB_OUTPUT
          {
            echo 'update_desc<<EOF'
            yq '.update_desc' release.yml
            echo EOF
          } >> "$GITHUB_OUTPUT"
          echo "VersionCode: $version_code"
          echo "VersionName: $version_name"
          echo "OnlineTime: $online_time"
          echo "UpdateDesc: ${update_desc}"
          
      - name: Upload VIVO
        uses: Mihuashi/upload-actions/vivo@main
        with:
          base_url: https://developer-api.vivo.com.cn/router/rest
          access_key: ${{ secrets.VIVO_ACCESS_KEY }}
          access_secret: ${{ secrets.VIVO_ACCESS_SECRET }}
          apk_file_path: mhs/build/outputs/apk/release/mhs-release.apk
          update_desc: ${{steps.version.outputs.update_desc}}
          online_time: ${{steps.version.outputs.online_time}}
```

## 相关参数

| 参数 | 是否必传 | 备注 |
| --- |---| --- |
| base_url | 是 | vivo 接口具体查看文档 https://dev.vivo.com.cn/documentCenter/doc/327 |
| access_key | 是 | access_key |
| access_secret | 是 | access_key |
| apk_file_path | 是 | apk 文件路径 |
| update_desc | 是 | 更新描述 |
| online_time | 否 | 上线时间 |
