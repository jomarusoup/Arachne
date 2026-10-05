################################################################################
# FILE NAME   : Makefile
# DESCRIPTION : 공유메모리 세그먼트·정렬 테이블 예제 빌드와 단위 테스트(make test)
################################################################################
# 리눅스와 macOS(clang) 모두에서 빌드된다. robust 뮤텍스(EOWNERDEAD) 테스트는
# 리눅스에서만 돈다 — macOS 에는 PTHREAD_MUTEX_ROBUST 가 없다.
# 새니타이저를 끄려면: make test SAN=

CC      ?= cc
CFLAGS  ?= -std=c11 -Wall -Wextra -Werror -g -O1
UNAME_S := $(shell uname -s)

# 컴파일러가 지원하면 ASan·UBSan 을 켠다
SAN_PROBE := $(shell printf 'int main(void){return 0;}' | \
               $(CC) -fsanitize=address,undefined -x c -o /dev/null - 2>/dev/null && echo yes)
ifeq ($(SAN_PROBE),yes)
SAN     ?= -fsanitize=address,undefined -fno-omit-frame-pointer
else
SAN     ?=
endif

LDLIBS  := -pthread
ifeq ($(UNAME_S),Linux)
LDLIBS  += -lrt
endif

TESTS   := test_sorted_table test_shm_segment

.PHONY: all test clean

all: $(TESTS)

test_sorted_table: test_sorted_table.c sorted_table.c sorted_table.h
	$(CC) $(CFLAGS) $(SAN) -o $@ test_sorted_table.c sorted_table.c $(LDLIBS)

test_shm_segment: test_shm_segment.c shm_segment.c sorted_table.c shm_segment.h sorted_table.h
	$(CC) $(CFLAGS) $(SAN) -o $@ test_shm_segment.c shm_segment.c sorted_table.c $(LDLIBS)

test: $(TESTS)
	./test_sorted_table
	./test_shm_segment

clean:
	rm -rf $(TESTS) *.dSYM
