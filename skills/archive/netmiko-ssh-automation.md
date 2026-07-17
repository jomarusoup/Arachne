---
name: netmiko-ssh-automation
description: 읽기 전용 수집·경계 있는 배치 SSH·TextFSM 파싱·보호된 설정 변경·타임아웃·에러 처리를 위한 안전한 Python Netmiko 패턴.
triggers:
  paths: ["**/*.py"]
  keywords: ["Netmiko", "SSH 자동화", "네트워크 장비", "show 명령"]
---

# Netmiko SSH 자동화

Netmiko로 네트워크 장치에 연결하는 Python 자동화를 작성하거나 검토할 때 사용한다.
기본 경로는 읽기 전용으로 유지하고, 설정 변경은 별도 변경 창·동료 검토·롤백 계획이 필요하다.

## 언제 사용하나

- 라우터·스위치·방화벽에서 `show` 명령 출력 수집
- 인터페이스·라우팅·설정 증거를 위한 소규모 감사 스크립트 작성
- 네트워크 SSH 스크립트에 타임아웃·예외 처리 추가
- TextFSM 템플릿이 있을 때 명령 출력 파싱
- 운영 장치에 적용 전 자동화 검토

## 안전 기본값

- 읽기 전용 `send_command()` 수집으로 시작
- 인벤토리는 작고 명시적으로 유지; 전체 주소 범위 스캔 금지
- 환경변수·볼트·`getpass` 사용; 자격증명 하드코딩 금지
- 연결 및 읽기 타임아웃 설정
- 구형 장치 과부하를 막기 위해 동시성 제한
- `send_config_set()` 전에 명시적 운영자 플래그 필수
- 변경 검증·승인 전까지 `save_config()` 호출 금지

## 읽기 전용 연결 패턴

```python
import os
from getpass import getpass
from netmiko import ConnectHandler
from netmiko.exceptions import (
    NetmikoAuthenticationException,
    NetmikoTimeoutException,
    ReadTimeout,
)

device = {
    "device_type": "cisco_ios",
    "host": "192.0.2.10",
    "username": os.environ.get("NETMIKO_USERNAME") or input("Username: "),
    "password": os.environ.get("NETMIKO_PASSWORD") or getpass("Password: "),
    "secret": os.environ.get("NETMIKO_ENABLE_SECRET"),
    "conn_timeout": 10,
    "auth_timeout": 20,
    "banner_timeout": 15,
    "read_timeout_override": 30,
}

try:
    with ConnectHandler(**device) as conn:
        if device.get("secret") and not conn.check_enable_mode():
            conn.enable()
        output = conn.send_command("show ip interface brief", read_timeout=30)
        print(output)
except NetmikoAuthenticationException:
    print("인증 실패")
except NetmikoTimeoutException:
    print("SSH 연결 타임아웃")
except ReadTimeout:
    print("명령 읽기 타임아웃")
```

## 배치 수집

```python
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Any

def collect_show(device: dict[str, Any], command: str) -> dict[str, Any]:
    host = device["host"]
    try:
        with ConnectHandler(**device) as conn:
            output = conn.send_command(command, read_timeout=45)
        return {"host": host, "ok": True, "output": output}
    except (NetmikoAuthenticationException, NetmikoTimeoutException, ReadTimeout) as exc:
        return {"host": host, "ok": False, "error": type(exc).__name__}

results = []
with ThreadPoolExecutor(max_workers=8) as pool:
    futures = [pool.submit(collect_show, device, "show version") for device in devices]
    for future in as_completed(futures):
        results.append(future.result())
```

장치 규모와 AAA 시스템이 높은 연결 볼륨을 처리할 수 있는지 알기 전까지 `max_workers`를 낮게 유지한다.

## 구조화된 파싱

```python
with ConnectHandler(**device) as conn:
    parsed = conn.send_command(
        "show ip interface brief",
        use_textfsm=True,
        raise_parsing_error=False,
        read_timeout=30,
    )

if isinstance(parsed, str):
    print("파서 템플릿 없음; 원본 출력 저장하여 검토")
else:
    for row in parsed:
        print(row)
```

파싱이 차단 결정을 주도하는 경우 불일치 검사를 위해 원본 출력을 파싱 결과와 함께 보관한다.

## 보호된 설정 패턴

```python
import os

commands = [
    "interface GigabitEthernet0/1",
    "description CHANGE-1234 UPLINK-TO-CORE",
]

apply_changes = os.environ.get("APPLY_NETWORK_CHANGES") == "1"

if not apply_changes:
    print("드라이런만 실행. 후보 명령:")
    print("\n".join(commands))
else:
    with ConnectHandler(**device) as conn:
        conn.enable()
        before = conn.send_command("show running-config interface GigabitEthernet0/1")
        output = conn.send_config_set(commands)
        after = conn.send_command("show running-config interface GigabitEthernet0/1")
        print(before)
        print(output)
        print(after)
        print("startup-config 저장 전에 동작을 검증하세요.")
```

## 검토 체크리스트

- 스크립트가 명시적 인벤토리 소스를 식별하는가?
- 소스·로그·예외 메시지에 자격증명이 없는가?
- `conn_timeout`, `auth_timeout`, 명령 `read_timeout`이 설정됐는가?
- 전체 배치를 중단하지 않고 장치별 실패를 보고하는가?
- 스크립트가 광범위한 스캔과 무한 동시성을 피하는가?
- 설정 변경이 드라이런 또는 명시적 운영자 플래그 뒤에 있는가?
- `save_config()`가 초기 푸시와 분리되어 검증에 연결됐는가?

## 안티패턴

- 소스에 비밀번호, enable 비밀, 개인 키 하드코딩
- 설정 명령을 기본 코드 경로로 전송
- 검토된 인벤토리 대신 CIDR 범위로 자동화 실행
- 삭제 없이 전체 running config를 공유 시스템에 로깅
- 파서 성공을 장치 상태 정확성의 증거로 취급
