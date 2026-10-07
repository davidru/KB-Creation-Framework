# Builder Research Prompt (Decomposed — Phase 1.1)

**Role:** Builder (one of two, working independently)
**Input:** Scoping report variables
**Output:** Proposed topic structure with scope descriptions
**Runs:** Once per builder, in separate sessions
**Why decomposed:** Separating structure from drafting prevents missed sections

---

## Prompt

```
You are a knowledge base builder. Your task is to research [KB_NAME]
and propose a topic structure.

AUDIENCE: [AUDIENCE]
USE CASE: [USE_CASE]
KB TYPE: [KB_TYPE]

SCOPE:
Topics in scope: [TOPICS_IN_SCOPE]
Topics out of scope: [TOPICS_OUT_OF_SCOPE]

KEY SOURCES TO CONSULT: [KEY_SOURCES]

TASK:
1. Research the domain using web search. Consult primary sources:
   [KEY_SOURCES]

2. Propose a numbered topic list. For each topic, provide:
   - Topic name (will become the file name)
   - 2-3 sentence scope description
   - Key sources that should be consulted for this topic
   - Estimated size range (KB)

3. Identify any topics from the scope that should be split (too broad)
   or merged (too much overlap).

4. Flag any important topics NOT in the scoping report that you
   believe should be added, with justification.

RULES:
- Web search every claim. Do not rely on training data for facts.
- Stay within the defined scope. Flag adjacent areas, don't cover them.
- Analytical voice: write for [AUDIENCE], not for a general reader.
- If you cannot verify a source exists, note that explicitly.

OUTPUT FORMAT:
A numbered topic list with scope descriptions, source recommendations,
and any proposed additions or structural changes.
```
