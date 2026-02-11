#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}📦 MulTab DMG 打包脚本${NC}"
echo ""

# 1. 清理旧文件
echo -e "${YELLOW}🧹 清理旧文件...${NC}"
rm -rf ./build/Build/Products/Release/MulTab.app
rm -f ./release/MulTab.dmg

# 2. 编译 Release 版本
echo -e "${YELLOW}🔨 编译 Release 版本...${NC}"
xcodebuild -project MulTab.xcodeproj \
  -scheme MulTab \
  -configuration Release \
  -derivedDataPath ./build \
  clean build

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ 编译失败！${NC}"
    exit 1
fi

echo -e "${GREEN}✅ 编译成功！${NC}"

# 3. 检查 create-dmg 是否安装
if ! command -v create-dmg &> /dev/null; then
    echo -e "${YELLOW}⚠️  create-dmg 未安装，正在安装...${NC}"
    brew install create-dmg
fi

# 4. 创建 release 目录
mkdir -p release

# 5. 创建 DMG
echo -e "${YELLOW}📦 创建 DMG 安装包...${NC}"
create-dmg \
  --volname "MulTab Installer" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "MulTab.app" 175 120 \
  --hide-extension "MulTab.app" \
  --app-drop-link 425 120 \
  --no-internet-enable \
  "./release/MulTab.dmg" \
  "./build/Build/Products/Release/MulTab.app"

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ DMG 打包成功！${NC}"
    echo -e "${GREEN}📁 输出位置: ./release/MulTab.dmg${NC}"
    
    # 获取文件大小
    SIZE=$(du -h ./release/MulTab.dmg | cut -f1)
    echo -e "${BLUE}📊 文件大小: ${SIZE}${NC}"
    
    # 打开 release 目录
    open ./release
else
    echo -e "${RED}❌ DMG 打包失败！${NC}"
    exit 1
fi
