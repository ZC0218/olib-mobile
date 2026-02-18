# AI 智阅锦囊 — 后端 API 接口规范

> 本文档定义前后端数据模型与接口契约，供后端开发使用。

---

## 一、数据模型

### 1.1 PrescribeRequest（客户端 → 后端）

用户发起推荐请求时发送的数据。

```json
{
  "input": "relax",
  "input_type": "theme",
  "language": "zh"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `input` | string | ✅ | 用户输入。可以是预设主题 ID（见下方主题表），也可以是自由描述文本 |
| `input_type` | string | ❌ | `"theme"` / `"free"` / `"auto"`（默认 `"auto"`）。`auto` 表示后端自行判断 |
| `language` | string | ❌ | `"zh"` / `"en"`，控制返回内容的语言。默认 `"zh"` |

### 1.2 ReadingTip（后端 → 客户端 · 单条推荐）

AI 生成的一条书籍推荐。

```json
{
  "book_name": "人间值得",
  "author": "中村恒子",
  "reason": "一位90岁心理医生的人生智慧，教你用轻松的心态面对压力。",
  "category": "治愈"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `book_name` | string | ✅ | 书名 |
| `author` | string | ✅ | 作者 |
| `reason` | string | ✅ | 推荐理由（1-2 句话） |
| `category` | string | ✅ | 分类标签，如 `治愈` / `思维` / `文学` / `小说` / `技能` 等 |

### 1.3 ReadingBag（后端 → 客户端 · 完整锦囊）

AI 返回的完整阅读锦囊，包含诊断语 + 推荐列表。

```json
{
  "diagnosis": "你需要给自己的心灵放个假，用文字的力量卸下肩上的重担。",
  "tips": [
    {
      "book_name": "人间值得",
      "author": "中村恒子",
      "reason": "一位90岁心理医生的人生智慧。",
      "category": "治愈"
    },
    {
      "book_name": "蛤蟆先生去看心理医生",
      "author": "Robert de Board",
      "reason": "用童话的方式讲述心理疗愈。",
      "category": "治愈"
    },
    {
      "book_name": "当下的力量",
      "author": "Eckhart Tolle",
      "reason": "帮助你放下焦虑，活在当下。",
      "category": "心灵"
    }
  ]
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `diagnosis` | string | ✅ | AI 对用户状态的诊断总结（1-2 句话） |
| `tips` | ReadingTip[] | ✅ | 推荐书籍列表，固定 **3 本** |

---

## 二、API 接口

### POST `/api/prescribe`

根据用户输入生成个性化阅读锦囊。

**Request**
```http
POST /api/prescribe
Content-Type: application/json

{
  "input": "工作压力大，最近总是失眠",
  "input_type": "free",
  "language": "zh"
}
```

**Response 200**
```json
{
  "success": true,
  "data": {
    "diagnosis": "看得出来你最近身心都很疲惫...",
    "tips": [
      {
        "book_name": "人间值得",
        "author": "中村恒子",
        "reason": "...",
        "category": "治愈"
      },
      { "..." : "..." },
      { "..." : "..." }
    ]
  }
}
```

**Response 4xx/5xx**
```json
{
  "success": false,
  "error": "Invalid input"
}
```

> [!IMPORTANT]
> 响应必须包裹在 `{ "success": bool, "data": ... }` 结构中，与前端 `ApiResponse` 对齐。

---

## 三、预设主题 ID 表

后端在 `input_type = "theme"` 时可直接匹配以下 ID，用于定制 AI Prompt。

| ID | Emoji | 中文 | English |
|----|-------|------|---------|
| `relax` | 😮‍💨 | 工作压力大，想放松 | Stressed, need to unwind |
| `direction` | 🤔 | 感到迷茫，想找方向 | Feeling lost, seeking direction |
| `learn` | 📈 | 想系统学习某个领域 | Want to learn a new skill |
| `bedtime` | 💤 | 睡前想读点轻松的 | Light bedtime reading |
| `heal` | 💔 | 情感低落，需要治愈 | Emotionally down, need comfort |
| `thinking` | 🎯 | 想提升认知和思维 | Sharpen my thinking |

---

## 四、后端实现要点

1. **AI 调用**：将 `input` 组装成 prompt 发给 LLM（OpenAI / Gemini / DeepSeek 等），要求返回固定 JSON 格式
2. **JSON 输出约束**：在 prompt 中明确要求 AI 返回 `{ "diagnosis": "...", "tips": [...] }` 结构
3. **推荐数量**：固定返回 3 本书
4. **language 字段**：控制 `diagnosis` 和 `reason` 的语言
5. **主题映射**：`input_type = "theme"` 时，可根据主题 ID 预先丰富 prompt 上下文
6. **错误处理**：AI 返回非法 JSON 时应重试或返回友好错误

### 建议的 Prompt 模板

```
你是一位资深阅读顾问。用户描述了当前状态："{input}"。

请推荐 3 本最适合的书，严格按以下 JSON 格式返回：
{
  "diagnosis": "一句话总结用户的状态和你的建议方向",
  "tips": [
    {
      "book_name": "书名",
      "author": "作者",
      "reason": "一句推荐理由",
      "category": "分类标签"
    }
  ]
}

要求：
- 只返回 JSON，不要包含其他文字
- tips 数组固定 3 项
- category 使用简短中文标签（如：治愈、思维、文学、技能、心灵、小说、随笔、管理、哲学、成长、心理、学习）
```

---

## 五、完整请求/响应示例

### 示例 1：预设主题

```json
// Request
{ "input": "relax", "input_type": "theme", "language": "zh" }

// Response
{
  "success": true,
  "data": {
    "diagnosis": "你需要给自己的心灵放个假，用文字的力量卸下肩上的重担。",
    "tips": [
      {
        "book_name": "人间值得",
        "author": "中村恒子",
        "reason": "一位90岁心理医生的人生智慧，教你用轻松的心态面对压力。",
        "category": "治愈"
      },
      {
        "book_name": "蛤蟆先生去看心理医生",
        "author": "Robert de Board",
        "reason": "用童话的方式讲述心理疗愈，轻松读完却有深刻启发。",
        "category": "治愈"
      },
      {
        "book_name": "当下的力量",
        "author": "Eckhart Tolle",
        "reason": "帮助你放下焦虑，活在当下，是全球畅销的减压必读书。",
        "category": "心灵"
      }
    ]
  }
}
```

### 示例 2：自由输入

```json
// Request
{ "input": "最近考研压力很大，不知道该怎么调整心态", "input_type": "free", "language": "zh" }

// Response
{
  "success": true,
  "data": {
    "diagnosis": "考研是一场马拉松，保持节奏比全力冲刺更重要。这三本书帮你找回内心的定力。",
    "tips": [
      {
        "book_name": "认知觉醒",
        "author": "周岭",
        "reason": "帮你建立科学的学习方法论，避免低效焦虑。",
        "category": "成长"
      },
      {
        "book_name": "被讨厌的勇气",
        "author": "岸见一郎",
        "reason": "教你放下外界期待，专注于自己能控制的事情。",
        "category": "心理"
      },
      {
        "book_name": "小王子",
        "author": "Antoine de Saint-Exupéry",
        "reason": "一本可以在疲惫时重新唤起初心的小书。",
        "category": "文学"
      }
    ]
  }
}
```
