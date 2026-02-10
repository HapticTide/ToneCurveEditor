# ToneCurveEditor 性能基线

更新时间：2026-02-10  
测试机环境：
- 架构：`arm64`
- 系统：`macOS 26.2 (25C56)`
- 数据规模：`1024 x 1024` 静态图

## 测试方法

- 使用 `scripts/run_benchmark.sh` 运行基准脚本。
- 每个渲染器预热 2 次后，连续采样 10 次。
- 统计平均、最小、最大耗时（单位 ms）。

## 本次结果

| Renderer | Avg (ms) | Min (ms) | Max (ms) | 说明 |
|---|---:|---:|---:|---|
| CIColorCube (64^3) | 73.40 | 71.36 | 84.03 | 正常 |
| Metal (LUT 1024) | - | - | - | 当前环境不可用 |

原始输出：

```text
[Benchmark][CIColorCube][1024x1024] avg=73.40ms min=71.36ms max=84.03ms
[Benchmark][Metal][1024x1024] unavailable
```

## 结论

- 在 Metal 不可用环境下，CIColorCube 在 1024x1024 约 70~80ms/帧。
- 若需更高实时性，建议在真机 Metal 环境复测，并将预览分辨率限制在 1024 或更低。
