---
name: thinking-modes
description: Guidelines for when to use extended thinking modes. Auto-invokes when planning complex features or debugging hard problems.
---

# Extended Thinking Modes

Claude Code has extended thinking that can be enabled on-demand.

## Thinking Budgets

| Keyword | Budget | Best For |
|---------|--------|----------|
| `think` | ~4K tokens | Simple planning, quick decisions |
| `think hard` / `think more` | ~10K tokens | Medium complexity planning |
| `think harder` / `think longer` | ~16K tokens | Complex analysis |
| `ultrathink` | ~32K tokens | Architecture, critical debugging |

## When to Use Extended Thinking

### Use `ultrathink` for:
- System architecture decisions
- Complex debugging (race conditions, memory leaks, state management)
- Large-scale refactoring planning
- Integration strategies across multiple systems
- Performance optimization analysis
- Unfamiliar codebase exploration
- Feature planning with many dependencies

### Use `think hard` for:
- Medium-complexity features
- API design decisions
- Database schema changes
- Component architecture
- Error handling strategies

### Use `think` for:
- Breaking down tasks
- Choosing between approaches
- Quick planning decisions

### Avoid extended thinking for:
- Simple code changes
- Well-specified tasks with clear steps
- Rapid prototyping iterations
- Bug fixes with obvious solutions
- Tasks where speed matters more than perfection

## Cost Awareness

Approximate cost per task:
- Standard: ~$0.02-0.05
- `think`: ~$0.06
- `think hard`: ~$0.15
- `ultrathink`: ~$0.30-0.50

Use extended thinking strategically for important decisions, not routine tasks.

## Enabling Thinking

**During session:**
- Press Tab key to toggle thinking mode on/off
- Or use keywords in prompts: "ultrathink about..."

**View thinking process:**
- Press Ctrl+O for verbose mode
