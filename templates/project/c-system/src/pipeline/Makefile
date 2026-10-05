################################################################################
# FILE NAME   : Makefile
# DESCRIPTION : 파이프라인 예제(SPSC 링버퍼·프레임 코덱) 빌드와 새니타이저 테스트
#                 make test  — ASan + UBSan 빌드로 두 테스트 실행
#                 make tsan  — TSan 빌드로 링버퍼 2스레드 테스트 실행 (미지원이면 건너뜀)
#                 make clean — 산출물 삭제
#               Linux gcc 와 macOS clang 에서 같은 명령으로 동작한다.
################################################################################

CC       ?= cc
BUILD    := build
STD      := -std=c11 -D_POSIX_C_SOURCE=200809L
WARN     := -Wall -Wextra -Werror
BASE     := $(STD) $(WARN) -g -O1 -fno-omit-frame-pointer -pthread
ASAN     := -fsanitize=address,undefined -fno-sanitize-recover=undefined
TSAN     := -fsanitize=thread

RING_SRC  := spsc_ring.c test_spsc_ring.c
FRAME_SRC := frame_codec.c test_frame_codec.c
HDRS      := spsc_ring.h frame_codec.h

.PHONY: all test tsan clean

all: $(BUILD)/test_spsc_ring $(BUILD)/test_frame_codec

$(BUILD):
	mkdir -p $(BUILD)

#--- ASan + UBSan 빌드 ---------------------------------------------------------
$(BUILD)/test_spsc_ring: $(RING_SRC) $(HDRS) | $(BUILD)
	$(CC) $(BASE) $(ASAN) -o $@ $(RING_SRC)

$(BUILD)/test_frame_codec: $(FRAME_SRC) $(HDRS) | $(BUILD)
	$(CC) $(BASE) $(ASAN) -o $@ $(FRAME_SRC)

test: all
	./$(BUILD)/test_spsc_ring
	./$(BUILD)/test_frame_codec

#--- TSan 빌드 — 컴파일러가 지원하지 않으면 건너뛴다 -----------------------------
$(BUILD)/tsan_spsc_ring: $(RING_SRC) $(HDRS) | $(BUILD)
	$(CC) $(BASE) $(TSAN) -o $@ $(RING_SRC)

tsan: | $(BUILD)
	@if printf 'int main(void){return 0;}\n' | $(CC) $(TSAN) -x c - -o $(BUILD)/tsan_probe 2>/dev/null; then \
		$(MAKE) --no-print-directory $(BUILD)/tsan_spsc_ring && ./$(BUILD)/tsan_spsc_ring; \
	else \
		echo "[SKIP] $(CC) 가 -fsanitize=thread 를 지원하지 않는다"; \
	fi

clean:
	rm -rf $(BUILD)
