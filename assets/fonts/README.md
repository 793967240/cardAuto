# 字体资产

## 已包含（可直接使用）

| 文件 | 用途 | 大小 |
|------|------|------|
| `cormorant_garamond_regular.ttf` | 英文正文（衬线，古典感） | ~297KB |
| `cormorant_garamond_bold.ttf` | 英文标题 | ~297KB |

## 需手动下载（因文件过大不入 Git）

### 思源宋体 SC（中文）

```bash
# 方式一：从官方 Release 下载 SubsetOTF（推荐，约 7MB）
# https://github.com/adobe-fonts/source-han-serif/releases
# 下载 09_SourceHanSerifSC.zip，解压取 SourceHanSerifSC-Regular.otf

# 方式二：Homebrew
brew install --cask font-source-han-serif

# 下载后执行子集化（需先 pip install fonttools）：
cd project/
python3 tools/font_subset.py
```

子集化后产物 `source_han_serif_subset.otf` 约 **3-5MB**，该文件可提交 Git。

## .gitignore 说明

完整字体包（>5MB）已加入 .gitignore，子集化后的文件不受此限制。
