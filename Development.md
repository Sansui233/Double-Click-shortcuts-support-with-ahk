在 CLIPStudioPaint.exe 中，实现键的长按、点按，双击，组合

## 配置

生效App：`CLIPStudioPaint.exe`。非 `CLIPStudioPaint.exe` 窗口激活状态下，不经过此脚本的判定。

按键重映射列表：
```ahk
KEY_MAPPINGS := [
    {type: "double-click", source: "a", target_type: "click", target: "^+n"},
    {type: "combine", source: "ax", target_type: "click", target: "{Delete}"},
    {type: "long-press", source: "a", target_type: "long-press", target: "a"}
]
```

忽略列表，不用于触发按键重映射的 key：
```json
IGNORE_KEYS := ["b", "c", "e", "x", "z"]
```
- "xa" 中 "x" 将不会被处理，按下即传递以降低延时。但 "ax" a 按下后，x 依然会被脚本处理。

### 配置说明
每一项都对应了：

```
{"映射前的物理操作"，"映射前的按键", "映射后的物理操作"，"映射后的按键"}
```

映射前的物理操作 可取值4种：`click``double-click``long-press``combine`
- 其中 `click``double-click``long-press`时，映射前的按键，只能是单个
- `combine` 时，映射前的按键必须是多个。

映射后的物理操作 可取值2种：`click``long-press`
- `click`对应映射后的按键可以是单个或多个
- `long-press`对应映射后的按键只能是单个

> ！限制：不能从 `click``double-click``combine` 映射为 `long-press`、

## 思路
模仿 Tourbox 的快捷键思路，

### Tourbox 设计

TourBox物理按键信号（keymap source）的设计逻辑很清晰，主要有以下三种基础操作：

1. **单击 (Single Click)**：最基础的按键操作。
2. **双击 (Double Click)**：快速连续按压两次。
3. **长按 (Long Press)**：按住按键不放。
4. **组合操作 (Combo)**：同时按下两个物理按键。

**双键组合限制**：TourBox仅支持**两个按键的组合**，系统不识别三键及以上的同时按下


### 默认操作透传

对于 `click``double-click``long-press``combine`,在没有定义按键映射列表的情况下，操作需要透传。也就是
- 检测到 `click` 了 `b`，但没有定义按键映射 `click` `b` 要干什么，就直接发送  b
- 检测到 `combine` 了 `a1`, 但没有定义按键映射 `combine` `a1` 要干什么，要干什么，就直接发送 a 和 1
- 检测到 `long-press` `c` 的 keydown，但没有定义 `long-press` `c` 映射为什么，就规则发送 `c` 的 keydown 和 keyup
- 检测到 `double-click` `a` ，就规则发送 `ctrl+shift+n`

## 代码流程

1. 根据配置说明, prune 按键映射列表，如果有错误要报错
2. 只捕获 csp 里的按键操作
3. 自己 dddebug history 状态机。多线程的会竞争 history。虽然可以上锁，但对于实际性要求比较高的场景，直接 throw 然后 debug。

## 语法要求

搜索并使用 autohotkey v2 的语法，不要使用 v1 的语法。参考：

- [autohotkey v2 Usage and Syntax](https://www.autohotkey.com/docs/v2/Program.htm)
- [quick reference](https://www.autohotkey.com/docs/v2/)
