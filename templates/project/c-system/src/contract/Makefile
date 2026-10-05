################################################################################
# FILE NAME   : Makefile
# DESCRIPTION : 스트림 계약 예제 빌드와 검증
#                 make test    — ASan + UBSan 빌드로 C 테스트 실행 (미지원이면 새니타이저 없이)
#                 make vectors — 헤더 정본에서 vectors/ 의 매니페스트·테스트 벡터를 다시 생성
#                 make layout  — 커밋된 매니페스트·벡터와 재생성 결과 비교 (check-layout.sh)
#                 make ts-test — 같은 벡터로 TypeScript 디코더 테스트 (node --test)
#                 make check   — 위 세 검증 전부
#                 make clean   — 산출물 삭제
#               Linux gcc 와 macOS clang 에서 같은 명령으로 동작한다.
################################################################################

CC       ?= cc
NODE     ?= node
BUILD    := build
STD      := -std=c11 -D_POSIX_C_SOURCE=200809L
WARN     := -Wall -Wextra -Werror
BASE     := $(STD) $(WARN) -g -O1 -fno-omit-frame-pointer

# 컴파일러가 지원하면 ASan·UBSan 을 켠다. 끄려면: make test SAN=
SAN_PROBE := $(shell printf 'int main(void){return 0;}' | \
               $(CC) -fsanitize=address,undefined -x c -o /dev/null - 2>/dev/null && echo yes)
ifeq ($(SAN_PROBE),yes)
SAN      ?= -fsanitize=address,undefined -fno-sanitize-recover=undefined
else
SAN      ?=
endif

LIB_SRC  := stream_msg.c
HDRS     := stream_msg.h

.PHONY: all test vectors layout ts-test check clean

all: $(BUILD)/test_stream_msg $(BUILD)/gen_vectors

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/test_stream_msg: $(LIB_SRC) test_stream_msg.c $(HDRS) | $(BUILD)
	$(CC) $(BASE) $(SAN) -o $@ $(LIB_SRC) test_stream_msg.c

$(BUILD)/gen_vectors: $(LIB_SRC) gen_vectors.c $(HDRS) | $(BUILD)
	$(CC) $(BASE) $(SAN) -o $@ $(LIB_SRC) gen_vectors.c

test: $(BUILD)/test_stream_msg
	./$(BUILD)/test_stream_msg

vectors: $(BUILD)/gen_vectors
	mkdir -p vectors
	./$(BUILD)/gen_vectors vectors

layout:
	bash ./check-layout.sh

ts-test:
	$(NODE) --test ts/decode.test.ts

check: test layout ts-test

clean:
	rm -rf $(BUILD)
