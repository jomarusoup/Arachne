################################################################################
# FILE NAME   : Makefile
# DESCRIPTION : 운영 로그 모듈 빌드·테스트 — C11, 경고를 에러로, ASan/UBSan(지원 시)
################################################################################
# 사용법:
#   make test        ASan/UBSan(컴파일러가 지원하면) 빌드로 단위 테스트 실행
#   make test-tsan   ThreadSanitizer 빌드로 단위 테스트 실행(비동기 모드 검증)
#   make clean

CC       ?= cc
CSTD     := -std=c11
WARN     := -Wall -Wextra -Werror -Wformat=2 -Wshadow -Wstrict-prototypes -Wpointer-arith
CFLAGS   ?= -O1 -g
LDLIBS   := -pthread

# 컴파일러가 지원할 때만 새니타이저를 켠다(작은 프로그램을 실제로 링크해 본다)
COMMA      := ,
SAN_PROBE  = printf 'int main(void){return 0;}\n' | $(CC) $(1) -x c - -o san_probe.out >/dev/null 2>&1 && echo $(1); rm -f san_probe.out
ASAN_FLAGS := $(shell $(call SAN_PROBE,-fsanitize=address$(COMMA)undefined))
TSAN_FLAGS := $(shell $(call SAN_PROBE,-fsanitize=thread))

SRCS     := log.c test_log.c
HDRS     := log.h

.PHONY: all test test-tsan clean

all: log.o

log.o: log.c $(HDRS)
	$(CC) $(CSTD) $(WARN) $(CFLAGS) -c log.c -o $@

test_log: $(SRCS) $(HDRS)
	$(CC) $(CSTD) $(WARN) $(CFLAGS) $(ASAN_FLAGS) -fno-omit-frame-pointer $(SRCS) -o $@ $(LDLIBS)

test_log_tsan: $(SRCS) $(HDRS)
	$(CC) $(CSTD) $(WARN) $(CFLAGS) $(TSAN_FLAGS) $(SRCS) -o $@ $(LDLIBS)

test: test_log
	@echo "[test] sanitizer: $(if $(ASAN_FLAGS),$(ASAN_FLAGS),없음)"
	UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1 ./test_log

test-tsan: test_log_tsan
	@echo "[test] sanitizer: $(if $(TSAN_FLAGS),$(TSAN_FLAGS),없음)"
	TSAN_OPTIONS=halt_on_error=1 ./test_log_tsan

clean:
	rm -rf log.o test_log test_log_tsan *.dSYM test_tmp.*
