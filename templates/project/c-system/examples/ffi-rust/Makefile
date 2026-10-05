#############################################################################
# FILE NAME   : Makefile
# DESCRIPTION : C·Rust 카운터 구현 빌드와 비교 테스트 (make test)
#############################################################################

CC       ?= cc
CFLAGS   ?= -std=c11 -Wall -Wextra -Werror -O2 -g
CPPFLAGS += -Iinclude
CARGO    ?= cargo

BUILD     := build
RUST_DIR  := rust
RUST_LIB  := $(RUST_DIR)/target/release/libcounter_rs.a
C_SRCS    := src/counter.c src/counter_mem.c tests/test_counter.c

HAVE_CARGO := $(shell command -v $(CARGO) 2>/dev/null)

#----------------------------------------------------------------------------
# Rust staticlib이 기대하는 시스템 라이브러리 — 정확한 목록은
# cargo rustc --release -- --print native-static-libs 로 확인한다
#----------------------------------------------------------------------------
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
    RUST_LDLIBS := -liconv -lm
else
    RUST_LDLIBS := -lgcc_s -lutil -lrt -lpthread -lm -ldl -lc
endif

.PHONY: all test test-c test-ffi rust-test clean FORCE

all: test

#----------------------------------------------------------------------------
# cargo가 없으면 Rust 비교를 건너뛰고 C 구현만 검사한다
#----------------------------------------------------------------------------
test:
ifeq ($(HAVE_CARGO),)
	@echo "[ffi-rust] cargo 없음 — Rust 빌드·비교를 건너뛰고 C 구현만 검사합니다."
	@$(MAKE) --no-print-directory test-c
else
	@$(MAKE) --no-print-directory rust-test test-ffi
endif

test-c: $(BUILD)/test_c
	./$(BUILD)/test_c

test-ffi: $(BUILD)/test_ffi
	./$(BUILD)/test_ffi

rust-test:
	$(CARGO) test --quiet --manifest-path $(RUST_DIR)/Cargo.toml

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/test_c: $(C_SRCS) include/counter.h | $(BUILD)
	$(CC) $(CPPFLAGS) $(CFLAGS) -o $@ $(C_SRCS)

$(BUILD)/test_ffi: $(C_SRCS) include/counter.h include/counter_rs.h $(RUST_LIB) | $(BUILD)
	$(CC) $(CPPFLAGS) $(CFLAGS) -DWITH_RUST -o $@ $(C_SRCS) $(RUST_LIB) $(RUST_LDLIBS)

# 재빌드 판단은 cargo에 맡긴다
$(RUST_LIB): FORCE
	$(CARGO) build --release --quiet --manifest-path $(RUST_DIR)/Cargo.toml

FORCE:

clean:
	rm -rf $(BUILD)
	-$(CARGO) clean --manifest-path $(RUST_DIR)/Cargo.toml 2>/dev/null
