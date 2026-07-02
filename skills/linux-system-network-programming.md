---
name: linux-system-network-programming
description: Linux 시스템/네트워크 프로그래밍 학습·리뷰 스킬. POSIX, socket, nonblocking I/O, epoll, signal, thread, memory, syscall 경계를 다룬다.
triggers:
  paths: ["**/*.c", "**/*.h"]
  keywords: ["POSIX", "socket", "signal", "fd 수명", "시스템 프로그래밍"]
---

# Linux System / Network Programming

Linux 시스템 프로그래밍과 네트워크 프로그래밍을 학습하거나 코드 리뷰할 때 사용하는 기준이다.

## 언제 사용하나

- C/C++ socket server, daemon, CLI, worker를 작성할 때
- `select`, `poll`, `epoll`, nonblocking I/O를 다룰 때
- signal, process, thread, mutex, condition variable을 사용할 때
- file descriptor, memory ownership, syscall error handling을 리뷰할 때
- latency, throughput, backpressure가 중요한 서버를 만들 때

## 기본 사고 순서

1. 리소스 수명: fd, memory, thread, process, lock의 owner를 정한다.
2. 실패 경로: 모든 syscall의 `-1`과 `errno`를 처리한다.
3. 블로킹 경계: 어떤 호출이 block될 수 있는지 표시한다.
4. backpressure: 읽기·쓰기 큐가 커질 때 정책을 정한다.
5. 종료 경로: signal, timeout, peer close, partial write를 검증한다.
6. 관측성: connection count, queue depth, error counter, p95 latency를 남긴다.

## Socket 체크리스트

- [ ] `SO_REUSEADDR`/`SO_REUSEPORT` 사용 이유가 명확하다.
- [ ] `accept4(..., SOCK_NONBLOCK | SOCK_CLOEXEC)` 또는 동등 처리를 사용한다.
- [ ] fd leak 방지를 위해 `CLOEXEC`를 설정한다.
- [ ] partial read/write를 처리한다.
- [ ] `EINTR`, `EAGAIN`, `EWOULDBLOCK` 분기가 있다.
- [ ] peer close를 정상 이벤트로 처리한다.
- [ ] message framing이 명확하다. TCP를 message boundary로 오해하지 않는다.

## epoll 체크리스트

- [ ] level-triggered와 edge-triggered 중 선택 이유가 있다.
- [ ] edge-triggered면 `EAGAIN`까지 drain한다.
- [ ] write 관심사는 항상 켜두지 않고 필요할 때만 켠다.
- [ ] timerfd/eventfd/signalfd 사용 여부를 검토한다.
- [ ] per-connection state machine이 있다.

## Signal / Process

- signal handler에서는 async-signal-safe 함수만 호출한다.
- 복잡한 종료 처리는 self-pipe, signalfd, event loop notification으로 넘긴다.
- child process를 만들면 `waitpid` 또는 SIGCHLD 처리로 zombie를 방지한다.

## Memory / Thread

- ownership transfer를 함수명과 주석에 드러낸다.
- shared mutable state는 최소화하고 lock order를 문서화한다.
- thread 종료와 join 경로를 테스트한다.
- C/C++ 코드는 ASan/TSan/UBSan 또는 valgrind를 검증 루프에 포함한다.

## 검증 명령 예시

```bash
gcc -Wall -Wextra -Werror -fsanitize=address,undefined -g -o app main.c
clang-tidy src/*.c
valgrind --leak-check=full ./app
strace -f ./app
ss -tnlp
```

## 관련 스킬

- [latency-critical-systems](latency-critical-systems.md)
- [memory-check](memory-check.md)
- [build-debug](build-debug.md)
- [network-interface-health](network-interface-health.md)
