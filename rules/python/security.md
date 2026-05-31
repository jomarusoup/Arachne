---
paths:
  - "**/*.py"
  - "**/*.pyi"
---
# Python 보안

> [common/security.md](../common/security.md) 를 확장한다.

## 비밀값 관리

```python
import os
from dotenv import load_dotenv

load_dotenv()

api_key = os.environ["API_KEY"]  # 없으면 KeyError 발생 (의도적)
```

## SQL 인젝션 방지

```python
# BAD
cursor.execute(f"SELECT * FROM users WHERE id = {user_id}")

# GOOD
cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))
```

## 입력 검증

```python
from pydantic import BaseModel, EmailStr

class UserInput(BaseModel):
    email: EmailStr
    age:   int

    @validator("age")
    def age_must_be_positive(cls, v: int) -> int:
        if v < 0:
            raise ValueError("나이는 0 이상이어야 합니다")
        return v
```

## 정적 보안 분석

```bash
bandit -r src/
safety check
```
