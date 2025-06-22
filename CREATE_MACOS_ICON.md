# macOS 应用图标制作指南

本指南详细记录了如何从一个原始 logo 图片制作符合 macOS 设计规范的应用图标。

## 背景知识

### macOS 图标设计规范
- **画布尺寸**: 1024×1024 像素
- **内容区域**: 832×832 像素（占画布的 83%）
- **留白区域**: 四周各 96 像素透明缓冲区
- **背景要求**: 不能有透明背景（Dock 中会显示异常）
- **形状**: macOS 会自动应用圆角（squircle）

### 为什么需要留白？
- 系统图标都有统一的视觉大小
- 没有留白的图标在 Dock 中会显得比其他图标大
- 留白区域让图标之间有适当的视觉间距

## 制作流程

### 1. 准备原始 Logo

确保你有一个高质量的 logo 文件（建议至少 1024×1024 像素）。

```bash
# 检查原始图片尺寸
sips -g pixelWidth -g pixelHeight logo.png
```

### 2. 创建正方形版本

如果原始 logo 不是正方形，需要先处理成正方形：

```bash
# 获取图片尺寸
WIDTH=$(sips -g pixelWidth logo.png | tail -n1 | cut -d' ' -f4)
HEIGHT=$(sips -g pixelHeight logo.png | tail -n1 | cut -d' ' -f4)

# 取较小的边作为正方形尺寸
SIZE=$((WIDTH < HEIGHT ? WIDTH : HEIGHT))

# 裁剪成正方形
sips -c $SIZE $SIZE logo.png --out logo_square.png
```

### 3. 调整图标大小并添加留白

创建 Swift 脚本来处理图标（create_icon.swift）：

```swift
#!/usr/bin/swift

import AppKit

// 配置
let canvasSize = CGSize(width: 1024, height: 1024)
let iconSize = CGSize(width: 832, height: 832)  // 83% of canvas

// 加载原始图片
guard let sourceImage = NSImage(contentsOfFile: CommandLine.arguments[1]) else {
    print("Error: Please provide an image file path")
    exit(1)
}

// 创建带透明背景的新图片
let paddedImage = NSImage(size: canvasSize)

paddedImage.lockFocus()

// 居中绘制图标
let x = (canvasSize.width - iconSize.width) / 2
let y = (canvasSize.height - iconSize.height) / 2
let drawRect = NSRect(x: x, y: y, width: iconSize.width, height: iconSize.height)

sourceImage.draw(in: drawRect)

paddedImage.unlockFocus()

// 保存为 PNG
if let tiffData = paddedImage.tiffRepresentation,
   let bitmapRep = NSBitmapImageRep(data: tiffData),
   let pngData = bitmapRep.representation(using: .png, properties: [:]) {
    try? pngData.write(to: URL(fileURLWithPath: "icon_base.png"))
    print("Created icon_base.png with transparent padding")
}
```

运行脚本：

```bash
# 先调整原始图片到 832×832
sips -Z 832 logo_square.png --out logo_832.png

# 使用 Swift 脚本添加留白
swift create_icon.swift logo_832.png
```

### 4. 生成所有需要的尺寸

创建自动化脚本（generate_icons.sh）：

```bash
#!/bin/bash

# 确保在 AppIcon.appiconset 目录中运行
ICON_DIR="Airchat/Assets.xcassets/AppIcon.appiconset"
cd "$ICON_DIR" || exit 1

# 基础图标路径（1024×1024 带留白的图标）
BASE_ICON="../../../icon_base.png"

# 生成所有尺寸
echo "Generating all icon sizes..."

# 1024×1024 (512pt @2x)
cp "$BASE_ICON" icon_512x512@2x.png

# 512×512 (512pt @1x, 256pt @2x)
sips -z 512 512 icon_512x512@2x.png --out icon_512x512.png
cp icon_512x512.png icon_256x256@2x.png

# 256×256 (256pt @1x, 128pt @2x)
sips -z 256 256 icon_512x512@2x.png --out icon_256x256.png
cp icon_256x256.png icon_128x128@2x.png

# 128×128 (128pt @1x)
sips -z 128 128 icon_512x512@2x.png --out icon_128x128.png

# 64×64 (32pt @2x)
sips -z 64 64 icon_512x512@2x.png --out icon_32x32@2x.png

# 32×32 (32pt @1x, 16pt @2x)
sips -z 32 32 icon_512x512@2x.png --out icon_32x32.png
cp icon_32x32.png icon_16x16@2x.png

# 16×16 (16pt @1x)
sips -z 16 16 icon_512x512@2x.png --out icon_16x16.png

echo "All icons generated!"
```

### 5. 处理透明背景问题（可选）

如果需要不透明的背景（解决 Dock 中透明显示的问题）：

```bash
# 在 AppIcon.appiconset 目录中
for file in *.png; do
    # 转换为 JPEG 再转回 PNG 以移除 alpha 通道
    sips -s format jpeg "$file" --out temp.jpg
    sips -s format png temp.jpg --out "$file"
    rm temp.jpg
done

# 验证 alpha 通道已移除
sips -g hasAlpha icon_512x512@2x.png
```

### 6. 验证图标尺寸

```bash
# 检查几个关键尺寸
for size in "512x512@2x" "256x256" "128x128" "32x32" "16x16"; do
    echo -n "icon_$size.png: "
    sips -g pixelWidth -g pixelHeight "icon_$size.png" | grep pixel
done
```

### 7. 清理和刷新

```bash
# 清理临时文件
rm -f logo_square.png logo_832.png icon_base.png

# 刷新 Dock 显示新图标
killall Dock

# 清理 Xcode 缓存（如果需要）
rm -rf ~/Library/Developer/Xcode/DerivedData
```

## 完整的一键脚本

创建 `make_macos_icon.sh`：

```bash
#!/bin/bash

# 使用方法: ./make_macos_icon.sh logo.png

if [ $# -eq 0 ]; then
    echo "Usage: $0 <logo_image>"
    exit 1
fi

LOGO=$1
TEMP_DIR=$(mktemp -d)

echo "Processing $LOGO..."

# 1. 获取图片尺寸并创建正方形版本
WIDTH=$(sips -g pixelWidth "$LOGO" | tail -n1 | cut -d' ' -f4)
HEIGHT=$(sips -g pixelHeight "$LOGO" | tail -n1 | cut -d' ' -f4)
SIZE=$((WIDTH < HEIGHT ? WIDTH : HEIGHT))

sips -c $SIZE $SIZE "$LOGO" --out "$TEMP_DIR/square.png"

# 2. 缩放到 832×832（内容区域）
sips -Z 832 "$TEMP_DIR/square.png" --out "$TEMP_DIR/content.png"

# 3. 创建 Swift 脚本添加留白
cat > "$TEMP_DIR/add_padding.swift" << 'EOF'
#!/usr/bin/swift
import AppKit

let canvasSize = CGSize(width: 1024, height: 1024)
let iconSize = CGSize(width: 832, height: 832)

if let sourceImage = NSImage(contentsOfFile: CommandLine.arguments[1]) {
    let paddedImage = NSImage(size: canvasSize)
    paddedImage.lockFocus()
    let x = (canvasSize.width - iconSize.width) / 2
    let y = (canvasSize.height - iconSize.height) / 2
    sourceImage.draw(in: NSRect(x: x, y: y, width: iconSize.width, height: iconSize.height))
    paddedImage.unlockFocus()
    
    if let tiffData = paddedImage.tiffRepresentation,
       let bitmapRep = NSBitmapImageRep(data: tiffData),
       let pngData = bitmapRep.representation(using: .png, properties: [:]) {
        try? pngData.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
    }
}
EOF

swift "$TEMP_DIR/add_padding.swift" "$TEMP_DIR/content.png" "$TEMP_DIR/padded.png"

# 4. 生成所有尺寸
ICONSET_DIR="Airchat/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$ICONSET_DIR"

# 复制基础图标
cp "$TEMP_DIR/padded.png" "$ICONSET_DIR/icon_512x512@2x.png"

# 生成其他尺寸
cd "$ICONSET_DIR"
sips -z 512 512 icon_512x512@2x.png --out icon_512x512.png
sips -z 512 512 icon_512x512@2x.png --out icon_256x256@2x.png
sips -z 256 256 icon_512x512@2x.png --out icon_256x256.png
sips -z 256 256 icon_512x512@2x.png --out icon_128x128@2x.png
sips -z 128 128 icon_512x512@2x.png --out icon_128x128.png
sips -z 64 64 icon_512x512@2x.png --out icon_32x32@2x.png
sips -z 32 32 icon_512x512@2x.png --out icon_32x32.png
sips -z 32 32 icon_512x512@2x.png --out icon_16x16@2x.png
sips -z 16 16 icon_512x512@2x.png --out icon_16x16.png

# 5. 清理
rm -rf "$TEMP_DIR"

echo "Icon generation complete! Icons saved to $ICONSET_DIR"
echo "Remember to refresh Dock: killall Dock"
```

使用方法：

```bash
chmod +x make_macos_icon.sh
./make_macos_icon.sh logo.png
```

## 常见问题

### Q: 图标在 Dock 中显示为透明？
A: 运行透明背景移除步骤（第5步）。

### Q: 图标看起来比其他应用大？
A: 确保内容只占 832×832，周围有 96px 留白。

### Q: Xcode 报告图标尺寸错误？
A: 确保原始 logo 是正方形，或使用裁剪步骤。

### Q: 图标没有更新？
A: 运行 `killall Dock` 并清理 Xcode 缓存。

## 最佳实践

1. **使用高质量原图**: 至少 1024×1024 像素
2. **保持简洁**: 图标在小尺寸下应该清晰可辨
3. **遵循规范**: 83% 内容区域 + 17% 留白
4. **测试所有尺寸**: 在 Dock、Launchpad 和 Finder 中查看
5. **考虑深色模式**: 确保图标在两种模式下都清晰

## 参考资源

- [Apple Human Interface Guidelines - App Icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- [macOS Design Resources](https://developer.apple.com/design/resources/)