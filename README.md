# Double-Click-shortcuts-support-with-ahk

给字母和数字区的每个键都加上可定义长按、和双击的快捷键，同时不会影响原来的长按和短按，也不占用修饰键。

- 通过单手（16键）最多按一个键，能定义48个快捷键
- 通过单手（16键）最多按两个键，能定义288个快捷键

有了它，再也不用 `ctrl + z` 按到腱鞘炎啦！
有了它，再也不用 `ctrl + shift + alt + e` 啦！

## 运行

安装 auto hot key v2 后，双击运行 csp.ahk。

## 按键配置

修改 csp.ahk 中监听的 App:
```
TARGET_APP := "CLIPStudioPaint.exe"
```

修改 csp.ahk 中的按键重映射列表，具体规则见下一节：
```ahk
KEY_MAPPINGS := [
    {type: "double-click", source: "a", target_type: "click", target: "^+n"},
    {type: "combine", source: "ax", target_type: "click", target: "{Delete}"},
    {type: "long-press", source: "a", target_type: "long-press", target: "l"}
]
```

以上实现:
- 双击 `a` 转换为 `ctrl + shift + n`, 在 CSP 中等于新建图层
- 连续按 `ax` 等于按 `Delete` 删除画面内容
- 长按 `a` 在 CSP 中等于长按 `l`，临时切换套锁工具


修改 csp.ahk 中的前缀键忽略列表，永远不用于触发按键重映射的 key：
```
IGNORE_KEYS := ["b", "c", "e", "x", "z"]
```
> 上述配置中 "xa" 中 "x" 将不会被处理，按下即传递以降低延时。但 "ax" a 按下后，x 依然会被脚本处理。

## KEY_MAPPINGS 说明

KEY_MAPPINGS 每一项都对应了：

```
{"映射前的物理操作"，"映射前的按键", "映射后的物理操作"，"映射后的按键"}
```

人话为：
```
{"短按|长按|双击|组合键"，"手指按的什么键", "App内是按一次还是长按"，"App内登记的按键"}
```

1. 映射前的物理操作
可取值4种：`click``double-click``long-press``combine`
- 写`click``double-click``long-press`时，映射前的按键只能是单个
- 写`combine` 时，映射前的按键必须是多个。

2. 映射后的物理操作
可取值2种：`click``long-press`
- 写`click`时，映射后的按键可以是单个或多个
- 写`long-press`时，映射后的按键只能是单个

> ！限制：只有 longpress 能映射为 longpress。不能从 `click``double-click``combine` 映射为 `long-press`。


## 缺点

- 作为组合键快捷键首位的键，其短按功能会增加约 50ms-100ms 延时。组合键和长按键都建议绑定对短按要求不高的键。程序已经对不必要的延时最大程度进行了处理。
- 长键功能起始时间比原生长。
- 对纯英文的文本的快速输入有影响，中文、日文、韩文等没影响。

## License

GPL 3.0